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
    /// Downloads the models in a background session, so that they go on while the app is not in
    /// front (`plans/BACKGROUND_DICTATION.md`).
    @ObservationIgnored let fetcher: URLSessionFileFetcher

    /// The last result, which is on the clipboard.
    private(set) var lastOutcome: DictationOutcome?
    /// Whether a recording from a test file is running (debug builds only).
    private(set) var isFakeRecording = false
    @ObservationIgnored private var starting: Task<Void, Never>?
    @ObservationIgnored private let sampleAudio: URL?

    private init() {
        let cache =
            (try? HubCache.appContainer())
            ?? HubCache(root: FileManager.default.temporaryDirectory.appending(path: "hub"))
        let support = cache.root.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let fetcher = URLSessionFileFetcher.background(identifier: "dev.nowack.outloud.models")
        self.fetcher = fetcher
        let store = ModelStore(
            cache: cache, recordURL: support.appending(path: "Outloud/model-verification.json"),
            fetcher: fetcher)
        library = ModelLibrary(store: store)
        engines = Engines(store: store)
        let historyStore = HistoryStore(
            folder: (try? HistoryStore.defaultFolder())
                ?? support.appending(path: "Outloud/History"))
        history = HistoryModel(store: historyStore, settings: settings)
        dictation = DictationController(
            settings: settings, library: library, engines: engines, history: historyStore)
        #if DEBUG
            // A relative path is read from the app's `tmp/`, where `devicectl device copy to` puts it.
            sampleAudio = UserDefaults.standard.string(forKey: "OutloudSampleAudio").map {
                URL(filePath: $0, relativeTo: FileManager.default.temporaryDirectory)
            }
        #else
            sampleAudio = nil
        #endif
        library.onDelete = { [engines] model in engines.unload(model) }
        dictation.onHistoryChange = { [history] in Task { await history.refresh() } }
    }

    /// Reads the models and the history once; the App Intents call it too, since they may run
    /// before the interface. Every caller waits until the models' states are known, so that a
    /// recording started by the Action Button at launch does not see them all missing.
    func start() async {
        if starting == nil {
            // The model lives as long as the app, so the task holds it strongly.
            starting = Task { await load() }
        }
        await starting?.value
    }

    private func load() async {
        history.startExpiringEntries()
        await library.refresh()
        // A recording can start before these finish; the transcription model loads on demand.
        Task {
            await library.resumeDownloads()
            await dictation.preloadModels()
        }
        #if DEBUG
            // `-OutloudSampleAudio <file> -OutloudAutoDictate YES` dictates the file once at
            // launch, so that the end-to-end test plans can run without a microphone
            // (`apps/ios/e2e/README.md`).
            if sampleAudio != nil, UserDefaults.standard.bool(forKey: "OutloudAutoDictate") {
                Task {
                    await startRecording()
                    await stopRecording()
                }
            }
        #endif
    }

    var needsSetup: Bool {
        !settings.hasCompletedSetup || !dictation.hasRequiredModels
    }

    var isRecording: Bool { dictation.state == .recording || isFakeRecording }

    // MARK: Dictation

    func toggleRecording() async {
        // A recording started from another app ends with its Live Activity.
        if isRecording, BackgroundDictation.shared.isRunning {
            _ = await BackgroundDictation.shared.stop(viaShortcut: false)
        } else if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
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

    /// Cleans up text a shortcut hands over and keeps it in the history, without the clipboard:
    /// the shortcut copies what it returns.
    func cleanUpForShortcut(text: String) async -> DictationOutcome? {
        let outcome = await dictation.process(text: text)
        dictation.reset()
        return outcome
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
