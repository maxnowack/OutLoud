import AppKit
import Carbon.HIToolbox

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
    enum Event { case pressed, released, cancelled }

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var eventMonitors: [Any] = []
    private var isPressed = false
    /// While the chord is held: it turned out to be a different shortcut, so it does not start a
    /// recording again until ⌥ or ⌘ is released.
    private var chordSpoiled = false
    private var chordPressedAt: ContinuousClock.Instant?
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
        chordSpoiled = false
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
                let kind = GetEventKind(event)
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated {
                    monitor.handle(pressed: kind == UInt32(kEventHotKeyPressed))
                }
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
    private func watchChord() {
        let flags: (NSEvent) -> Void = { [weak self] event in
            MainActor.assumeIsolated { self?.modifiersChanged(event.modifierFlags) }
        }
        let keys: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.otherKeyPressed() }
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

    /// How long after ⌥ ⌘ another key still makes it a shortcut, such as ⌥ ⌘ D; after that the key
    /// is typed and the recording goes on (decided by the user, 2026-10-23).
    static let shortcutWindow: Duration = .seconds(1)

    private func modifiersChanged(_ flags: NSEvent.ModifierFlags) {
        let modifiers = flags.intersection([.shift, .control, .option, .command])
        let chord: NSEvent.ModifierFlags = [.option, .command]
        if modifiers == chord {
            guard !isPressed, !chordSpoiled else { return }
            isPressed = true
            chordPressedAt = .now
            onEvent(.pressed)
        } else if modifiers.isSuperset(of: chord) {
            // ⇧ or ⌃ joined ⌥ ⌘: a shortcut, at any time.
            cancelChord()
        } else {
            chordSpoiled = false
            if isPressed {
                isPressed = false
                onEvent(.released)
            }
        }
    }

    private func otherKeyPressed() {
        guard isPressed, let pressedAt = chordPressedAt,
            ContinuousClock.now - pressedAt < Self.shortcutWindow
        else { return }
        cancelChord()
    }

    private func cancelChord() {
        chordSpoiled = true
        guard isPressed else { return }
        isPressed = false
        onEvent(.cancelled)
    }
}
