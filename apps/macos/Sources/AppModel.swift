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
    let loginItem = LoginItem()
    @ObservationIgnored let engines: Engines

    /// The last result and how it was handed over, for the menu bar panel.
    private(set) var lastOutcome: DictationOutcome?
    private(set) var lastDelivery: AutoPaster.Delivery?
    /// The shortcut that works: the chosen one, its fallback while ⌥ ⌘ lacks Accessibility
    /// access (ADR 0020), or `nil` when another app holds it.
    private(set) var activeHotkey: HotkeyPreset? = .default
    private(set) var accessibilityTrusted = AutoPaster.isTrusted

    var hotkey: HotkeyPreset {
        didSet {
            UserDefaults.standard.set(hotkey.rawValue, forKey: "hotkey")
            registerHotkey()
        }
    }

    var hotkeyAvailable: Bool { activeHotkey != nil }
    /// Whether ⌥ ⌘ was chosen but ⌥ Space stands in for it, for want of Accessibility access.
    var hotkeyFallsBack: Bool { hotkey.isModifierChord && activeHotkey == .fallback }

    var autoPasteEnabled: Bool {
        didSet { UserDefaults.standard.set(autoPasteEnabled, forKey: "autoPaste") }
    }

    @ObservationIgnored private var hotkeyMonitor: HotkeyMonitor?
    /// When the held shortcut was pressed; `nil` once it is released.
    @ObservationIgnored private var recordingStarted: ContinuousClock.Instant?
    /// Counts the presses, so that a press can tell whether a later one came while it waited.
    @ObservationIgnored private var presses = 0
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
            case .cancelled: self.hotkeyCancelled()
            }
        }
        registerHotkey()
        // Ask for the microphone at the first launch, not at the first dictation.
        if sampleAudio == nil, MicrophonePermission.status == .undetermined {
            Task { _ = await MicrophonePermission.request() }
        }
        history.startExpiringEntries()
        await library.refresh()
        await library.resumeDownloads()
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
        // A recording without a held key — its release came while Outloud still waited — ends
        // with the next press, which then starts its own.
        if dictation.state == .recording, recordingStarted == nil {
            dictation.cancelRecording()
            overlay.hide()
        }
        guard !dictation.state.isBusy else { return }
        presses += 1
        let press = presses
        recordingStarted = .now
        if sampleAudio != nil {
            overlay.show()
            return
        }
        let started = await dictation.startRecording()
        // Released, or pressed again, while Outloud waited — for the microphone dialog, say:
        // this press no longer wants a recording, and its pill must not stay.
        guard press == presses, recordingStarted != nil else {
            if started { dictation.cancelRecording() }
            overlay.hide()
            return
        }
        if started {
            overlay.show()
        } else {
            overlay.showBriefly()
        }
    }

    /// Another key joined the shortcut — ⌥ ⌘ D, say —, so it was not meant as a dictation.
    func hotkeyCancelled() {
        guard recordingStarted != nil else { return }
        recordingStarted = nil
        dictation.cancelRecording()
        overlay.hide()
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
                self.refreshAccessibility()
                if self.accessibilityTrusted { return }
            }
        }
    }

    func refreshAccessibility() {
        let trusted = AutoPaster.isTrusted
        guard trusted != accessibilityTrusted else { return }
        accessibilityTrusted = trusted
        // ⌥ ⌘ works only with Accessibility access; it replaces or gives way to its fallback.
        if hotkey.isModifierChord { registerHotkey() }
    }

    private func registerHotkey() {
        activeHotkey = hotkeyMonitor?.register(hotkey)
    }
}
