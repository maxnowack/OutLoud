import Foundation
import Observation
import OutloudKit
import OutloudUI

/// The iOS app's state and the dictation flow (ADR 0003).
///
/// One instance serves the interface and the App Intents, which run in the same process.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let settings = OutloudSettings()
    let network = NetworkMonitor()
    let library: ModelLibrary
    let history: HistoryModel
    let dictation: DictationController
    @ObservationIgnored let engines: Engines

    /// The last result, which is on the clipboard.
    private(set) var lastOutcome: DictationOutcome?
    /// Whether a recording from a test file is running (debug builds only).
    private(set) var isFakeRecording = false
    @ObservationIgnored private var started = false
    @ObservationIgnored private let sampleAudio: URL?

    private init() {
        let cache =
            (try? HubCache.appContainer())
            ?? HubCache(root: FileManager.default.temporaryDirectory.appending(path: "hub"))
        let support = cache.root.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let store = ModelStore(
            cache: cache, recordURL: support.appending(path: "Outloud/model-verification.json"))
        library = ModelLibrary(store: store)
        engines = Engines(store: store)
        let historyStore = HistoryStore(
            folder: (try? HistoryStore.defaultFolder())
                ?? support.appending(path: "Outloud/History"))
        history = HistoryModel(store: historyStore, settings: settings)
        dictation = DictationController(
            settings: settings, library: library, engines: engines, history: historyStore)
        #if DEBUG
            sampleAudio = UserDefaults.standard.string(forKey: "OutloudSampleAudio").map {
                URL(filePath: $0)
            }
        #else
            sampleAudio = nil
        #endif
        library.onDelete = { [engines] model in engines.unload(model) }
        dictation.onHistoryChange = { [history] in Task { await history.refresh() } }
    }

    /// Reads the models and the history once; the App Intents call it too, since they may run
    /// before the interface.
    func start() async {
        guard !started else { return }
        started = true
        history.startExpiringEntries()
        await library.refresh()
        await dictation.preloadModels()
        #if DEBUG
            // `-OutloudSampleAudio <file> -OutloudAutoDictate YES` dictates the file once at
            // launch, so that the end-to-end test plans can run without a microphone
            // (`apps/ios/e2e/README.md`).
            if sampleAudio != nil, UserDefaults.standard.bool(forKey: "OutloudAutoDictate") {
                await startRecording()
                await stopRecording()
            }
        #endif
    }

    var needsSetup: Bool {
        !settings.hasCompletedSetup || !dictation.hasRequiredModels
    }

    var isRecording: Bool { dictation.state == .recording || isFakeRecording }

    // MARK: Dictation

    func toggleRecording() async {
        if isRecording { await stopRecording() } else { await startRecording() }
    }

    func startRecording() async {
        await start()
        guard !isRecording, !dictation.state.isBusy else { return }
        if sampleAudio != nil {
            isFakeRecording = true
            return
        }
        await dictation.startRecording()
    }

    func stopRecording() async {
        let outcome: DictationOutcome?
        if isFakeRecording, let sampleAudio {
            isFakeRecording = false
            let samples = (try? AudioFile.samples(of: sampleAudio)) ?? []
            outcome = await dictation.process(samples: samples)
        } else {
            outcome = await dictation.stopRecording()
        }
        if let outcome { deliver(outcome) }
    }

    /// Cleans up text that system dictation supplied and puts the result on the clipboard.
    @discardableResult
    func cleanUp(text: String) async -> DictationOutcome? {
        await start()
        guard let outcome = await dictation.process(text: text) else { return nil }
        deliver(outcome)
        return outcome
    }

    private func deliver(_ outcome: DictationOutcome) {
        Clipboard.copy(outcome.result)
        lastOutcome = outcome
    }
}
