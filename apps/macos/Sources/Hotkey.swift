import AppKit
import Carbon.HIToolbox
import OutloudKit

/// The push-to-talk shortcuts the user can choose from (ADR 0004, ADR 0020).
///
/// Carbon hot keys report both the press and the release without the Accessibility permission,
/// but need a key besides the modifiers. ⌥ ⌘ alone is watched through the modifier keys of every
/// app instead, which macOS reports only to an app with Accessibility access.
enum HotkeyPreset: String, CaseIterable, Identifiable {
    case optionCommand
    case optionSpace
    case controlOptionSpace
    case shiftOptionSpace

    static let `default`: HotkeyPreset = .optionCommand
    /// What works instead of ⌥ ⌘ while Accessibility access is missing.
    static let fallback: HotkeyPreset = .optionSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionCommand: "⌥ ⌘"
        case .optionSpace: "⌥ Space"
        case .controlOptionSpace: "⌃ ⌥ Space"
        case .shiftOptionSpace: "⇧ ⌥ Space"
        }
    }

    /// Whether the shortcut is modifiers alone, which needs Accessibility access.
    var isModifierChord: Bool { self == .optionCommand }

    fileprivate var keyCode: UInt32 { UInt32(kVK_Space) }

    fileprivate var modifiers: UInt32 {
        switch self {
        case .optionCommand, .optionSpace: UInt32(optionKey)
        case .controlOptionSpace: UInt32(controlKey | optionKey)
        case .shiftOptionSpace: UInt32(shiftKey | optionKey)
        }
    }
}

/// Registers the push-to-talk shortcut and reports when it is pressed and released, or cancelled
/// because another key joined it.
@MainActor
final class HotkeyMonitor {
    /// `pasteOnReturn` comes from the ⌥ ⌘ chord only (`plans/done/PASTE_ON_RETURN.md`).
    typealias Event = OptionCommandChord.Event

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var eventMonitors: [Any] = []
    /// Whether the Carbon hot key is held.
    private var isPressed = false
    private var chord = OptionCommandChord()
    private let onEvent: (Event) -> Void

    init(onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
    }

    /// Registers the shortcut, replacing the previous one, and returns the one that works: a
    /// modifier chord without Accessibility access gives way to `HotkeyPreset.fallback`. Returns
    /// `nil` when another app holds the shortcut already.
    @discardableResult
    func register(_ preset: HotkeyPreset) -> HotkeyPreset? {
        unregister()
        if preset.isModifierChord {
            if AXIsProcessTrusted() {
                watchChord()
                return preset
            }
            return registerHotKey(.fallback) ? .fallback : nil
        }
        return registerHotKey(preset) ? preset : nil
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors = []
        if let event = chord.reset() { onEvent(event) }
        if isPressed {
            isPressed = false
            onEvent(.released)
        }
    }

    // MARK: Carbon hot key

    private func registerHotKey(_ preset: HotkeyPreset) -> Bool {
        installHandlerIfNeeded()
        let identifier = EventHotKeyID(signature: OSType(0x4F75_746C), id: 1)  // "Outl"
        let status = RegisterEventHotKey(
            preset.keyCode, preset.modifiers, identifier, GetApplicationEventTarget(), 0, &hotKey)
        return status == noErr
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var types = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
                // Enqueued on the main actor rather than `MainActor.assumeIsolated`: its run-time
                // check crashed in these callbacks (see `watchChord`).
                Task { @MainActor in monitor.handle(pressed: pressed) }
                return noErr
            }, types.count, &types, context, &handler)
    }

    private func handle(pressed: Bool) {
        // A held key repeats its press; only the first press and the release count.
        guard pressed != isPressed else { return }
        isPressed = pressed
        onEvent(pressed ? .pressed : .released)
    }

    // MARK: Modifier chord

    /// Watches ⌥ ⌘ in every app (global monitors) and in Outloud's own windows (local ones).
    ///
    /// The handlers run on the main thread but enqueue their work on the main actor instead of
    /// calling `MainActor.assumeIsolated`: on macOS 27.0.1 its run-time check crashed now and
    /// then in these callbacks, reading an invalid executor (`EXC_BAD_ACCESS` in
    /// `swift_task_isMainExecutorImpl`, 0.2.0 and 0.2.2, 2026-10-26). Jobs enqueued from the main
    /// thread run in order, so a press is never handled after its release.
    private func watchChord() {
        let flags: (NSEvent) -> Void = { [weak self] event in
            let modifiers = event.modifierFlags.rawValue
            Task { @MainActor in
                guard let self else { return }
                self.chord.modifiersChanged(modifiers, at: .now).forEach(self.onEvent)
            }
        }
        let keys: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in
                guard let self, let event = self.chord.keyPressed(at: .now) else { return }
                self.onEvent(event)
            }
        }
        eventMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags),
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keys),
            NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
                flags($0)
                return $0
            },
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                keys($0)
                return $0
            },
        ].compactMap { $0 }
    }
}
