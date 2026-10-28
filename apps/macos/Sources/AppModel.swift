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
    /// The field focused when the recording started, which its result follows (ADR 0027).
    @ObservationIgnored private var target: AutoPaster.Target?
    @ObservationIgnored private var returnPaste = ReturnPaste<AutoPaster.Target>()
    /// The dictation processed in sight: its press, and its ticket when it follows a field.
    @ObservationIgnored private var inSight:
        (press: Int, ticket: ReturnPaste<AutoPaster.Target>.Ticket?)?
    @ObservationIgnored private var focusPolling: Task<Void, Never>?
    @ObservationIgnored let overlay = RecordingOverlay()
    @ObservationIgnored private let pauser = PlaybackPauser()
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
        dictation.onRecordingEnded = { [pauser] in pauser.resume() }
        overlay.bind(to: dictation, pauser: pauser)
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
        // The dictation processed in sight goes on out of sight, so that this one can start
        // (ADR 0027).
        if inSight != nil {
            inSight = nil
            dictation.continueInBackground()
        }
        guard !dictation.state.isBusy else { return }
        presses += 1
        let press = presses
        recordingStarted = .now
        target = AutoPaster.focusedTarget()
        if sampleAudio != nil {
            overlay.show()
            return
        }
        // Before the recording starts, so that a headset whose microphone it opens does not count
        // as playing (ADR 0024).
        if settings.pausesPlayback { pauser.pauseIfPlaying() }
        let started = await dictation.startRecording()
        if !started { pauser.resume() }
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
        // Taken now: a press while this one is processed starts over with its own.
        let press = presses
        let field = autoPasteEnabled ? target : nil
        var ticket: ReturnPaste<AutoPaster.Target>.Ticket?
        let outcome: DictationOutcome?
        if let sampleAudio, let samples = try? AudioFile.samples(of: sampleAudio) {
            inSight = (press, nil)
            outcome = await dictation.process(samples: samples)
        } else {
            guard dictation.state == .recording else { return }
            // A tap shorter than this was not meant as a dictation.
            if ContinuousClock.now - started < .milliseconds(250) {
                dictation.cancelRecording()
                overlay.hide()
                return
            }
            if let field {
                // The result follows the field: pasted there, at once or when the user is back
                // (ADR 0027).
                let followed = returnPaste.start(in: field)
                ticket = followed
                pollFocus()
                if returnPaste.goesToNextField(followed) {
                    // Its field is taken by an earlier dictation: out of sight, for the next one.
                    overlay.hide()
                    outcome = await dictation.stopRecordingInBackground()
                } else {
                    inSight = (press, followed)
                    outcome = await dictation.stopRecording()
                }
            } else {
                inSight = (press, nil)
                outcome = await dictation.stopRecording()
            }
        }
        let wasInSight = inSight?.press == press
        if wasInSight { inSight = nil }
        if let ticket {
            guard let outcome else {
                returnPaste.fail(ticket)
                // Out of sight, a failure shows no pill, which could cover the next recording's.
                if wasInSight { overlay.showBriefly() }
                return
            }
            lastOutcome = outcome
            returnPaste.finish(ticket, outcome.result)
            checkFocus()
            return
        }
        guard let outcome else {
            if wasInSight { overlay.showBriefly() }
            return
        }
        lastOutcome = outcome
        // Sent to the background by a new press, it is copied, so that nothing is pasted while
        // the user records.
        show(
            wasInSight
                ? AutoPaster.deliver(outcome.result, autoPaste: autoPasteEnabled)
                : AutoPaster.copy(outcome.result, autoPaste: autoPasteEnabled))
    }

    /// Shows how a result was handed over — not over the pill of a recording that started
    /// meanwhile, nor of a dictation processed in sight.
    private func show(_ delivery: AutoPaster.Delivery) {
        lastDelivery = delivery
        if recordingStarted == nil, inSight == nil { overlay.showDelivery(delivery) }
    }

    /// Watches the focused field while a dictation that follows one is processed or waits: the
    /// pill of the one in sight goes once the user leaves its field, and a result is pasted once
    /// its field has the focus again (ADR 0027).
    ///
    /// Polled rather than observed: an Electron app that shows another conversation keeps the
    /// same focused element, so no focus notification marks the user's return to the right one
    /// (measured in Claude, 2026-10-28). A check is a few Accessibility reads, and runs only while
    /// a result is processed or waits.
    private func pollFocus() {
        guard focusPolling == nil else { return }
        focusPolling = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, self.returnPaste.isActive else { break }
                self.checkFocus()
            }
            self?.focusPolling = nil
        }
    }

    /// Pastes, copies or says what waits, from the field focused now. Not while a recording is
    /// held: a ⌘V then would cancel it as a shortcut, and its pill has the screen.
    private func checkFocus() {
        guard recordingStarted == nil else { return }
        let focused = NSWorkspace.shared.frontmostApplication.flatMap {
            AutoPaster.focusedTarget(in: $0.processIdentifier)
        }
        for action in returnPaste.check(focused: focused) {
            switch action {
            case .paste(let text): show(AutoPaster.deliver(text, autoPaste: true))
            case .copy(let text): show(AutoPaster.copy(text, autoPaste: true))
            case .leftField(let ticket, let field):
                if let sight = inSight, sight.ticket == ticket {
                    inSight = nil
                    dictation.continueInBackground()
                }
                let app = NSRunningApplication(processIdentifier: field.pid)?.localizedName ?? ""
                show(.waiting(app: app))
            }
        }
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
