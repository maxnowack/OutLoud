import AppKit
import Observation
import OutloudKit

/// The macOS app's state and the push-to-talk flow (ADR 0004).
@MainActor
@Observable
final class AppModel {
    let settings = OutloudSettings()
    let network = NetworkMonitor()
    let library: ModelLibrary
    let history: HistoryModel
    let dictation: DictationController
    @ObservationIgnored let engines: Engines

    /// The last result and how it was handed over, for the menu bar panel.
    private(set) var lastOutcome: DictationOutcome?
    private(set) var lastDelivery: AutoPaster.Delivery?
    /// Whether the push-to-talk shortcut could be registered.
    private(set) var hotkeyAvailable = true
    private(set) var accessibilityTrusted = AutoPaster.isTrusted

    var hotkey: HotkeyPreset {
        didSet {
            UserDefaults.standard.set(hotkey.rawValue, forKey: "hotkey")
            hotkeyAvailable = hotkeyMonitor?.register(hotkey) ?? false
        }
    }

    var autoPasteEnabled: Bool {
        didSet { UserDefaults.standard.set(autoPasteEnabled, forKey: "autoPaste") }
    }

    @ObservationIgnored private var hotkeyMonitor: HotkeyMonitor?
    @ObservationIgnored private var recordingStarted: ContinuousClock.Instant?
    @ObservationIgnored let overlay = RecordingOverlay()
    @ObservationIgnored private var trustPolling: Task<Void, Never>?
    /// A recording to process instead of the microphone, for testing (debug builds only).
    @ObservationIgnored private let sampleAudio: URL?

    init() {
        let support =
            (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                create: true))
            ?? FileManager.default.temporaryDirectory
        let store = ModelStore(
            cache: .shared(),
            recordURL: support.appending(path: "Outloud/model-verification.json"))
        library = ModelLibrary(store: store)
        engines = Engines(store: store)
        let historyStore = HistoryStore(
            folder: (try? HistoryStore.defaultFolder())
                ?? support.appending(path: "Outloud/History"))
        history = HistoryModel(store: historyStore, settings: settings)
        dictation = DictationController(
            settings: settings, library: library, engines: engines, history: historyStore)
        hotkey =
            UserDefaults.standard.string(forKey: "hotkey").flatMap(HotkeyPreset.init(rawValue:))
            ?? .default
        autoPasteEnabled =
            UserDefaults.standard.object(forKey: "autoPaste") == nil
            ? true : UserDefaults.standard.bool(forKey: "autoPaste")
        #if DEBUG
            sampleAudio = UserDefaults.standard.string(forKey: "OutloudSampleAudio").map {
                URL(filePath: $0)
            }
        #else
            sampleAudio = nil
        #endif

        library.onDelete = { [engines] model in engines.unload(model) }
        dictation.onHistoryChange = { [history] in Task { await history.refresh() } }
        overlay.bind(to: dictation)
    }

    /// Everything the app does once at launch.
    func start() async {
        hotkeyMonitor = HotkeyMonitor { [weak self] event in
            guard let self else { return }
            switch event {
            case .pressed: Task { await self.hotkeyPressed() }
            case .released: Task { await self.hotkeyReleased() }
            }
        }
        hotkeyAvailable = hotkeyMonitor?.register(hotkey) ?? false
        history.startExpiringEntries()
        await library.refresh()
        #if DEBUG
            let preloadStart = ContinuousClock.now
        #endif
        await dictation.preloadModels()
        #if DEBUG
            let preloaded = ContinuousClock.now - preloadStart
            // `-OutloudSampleAudio <file> -OutloudAutoDictate YES` dictates the file once at
            // launch, as if the shortcut had been held, so that the end-to-end test plans can
            // run without a microphone (`apps/macos/e2e/README.md`).
            if sampleAudio != nil, UserDefaults.standard.bool(forKey: "OutloudAutoDictate") {
                let dictationStart = ContinuousClock.now
                await hotkeyPressed()
                await hotkeyReleased()
                print(
                    "OutloudAutoDictate: models loaded in \(preloaded), dictated in \(ContinuousClock.now - dictationStart), delivery \(String(describing: lastDelivery))"
                )
                if UserDefaults.standard.bool(forKey: "OutloudQuitAfterAutoDictate") {
                    NSApp.terminate(nil)
                }
            }
        #endif
    }

    var needsSetup: Bool {
        !settings.hasCompletedSetup || !dictation.hasRequiredModels
    }

    // MARK: Push to talk

    func hotkeyPressed() async {
        guard !dictation.state.isBusy else { return }
        if sampleAudio != nil {
            recordingStarted = .now
            overlay.show()
            return
        }
        recordingStarted = .now
        if await dictation.startRecording() {
            overlay.show()
        } else {
            overlay.showBriefly()
        }
    }

    func hotkeyReleased() async {
        guard let started = recordingStarted else { return }
        recordingStarted = nil
        let outcome: DictationOutcome?
        if let sampleAudio, let samples = try? AudioFile.samples(of: sampleAudio) {
            outcome = await dictation.process(samples: samples)
        } else {
            guard dictation.state == .recording else { return }
            // A tap shorter than this was not meant as a dictation.
            if ContinuousClock.now - started < .milliseconds(250) {
                dictation.cancelRecording()
                overlay.hide()
                return
            }
            outcome = await dictation.stopRecording()
        }
        guard let outcome else {
            overlay.showBriefly()
            return
        }
        lastOutcome = outcome
        let delivery = await AutoPaster.deliver(outcome.result, autoPaste: autoPasteEnabled)
        lastDelivery = delivery
        overlay.showDelivery(delivery)
    }

    // MARK: Accessibility

    func requestAccessibility() {
        AutoPaster.requestTrust()
        trustPolling?.cancel()
        trustPolling = Task { [weak self] in
            for _ in 0..<120 {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.accessibilityTrusted = AutoPaster.isTrusted
                if self.accessibilityTrusted { return }
            }
        }
    }

    func refreshAccessibility() {
        accessibilityTrusted = AutoPaster.isTrusted
    }
}
