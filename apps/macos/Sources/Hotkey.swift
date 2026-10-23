import AppKit
import Carbon.HIToolbox

/// The push-to-talk shortcuts the user can choose from (ADR 0004).
///
/// Carbon hot keys report both the press and the release without the Accessibility permission,
/// which the app must work without; they need a key besides the modifiers, so a modifier alone
/// cannot be the shortcut.
enum HotkeyPreset: String, CaseIterable, Identifiable {
    case optionSpace
    case controlOptionSpace
    case shiftOptionSpace

    static let `default`: HotkeyPreset = .optionSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .controlOptionSpace: "⌃ ⌥ Space"
        case .shiftOptionSpace: "⇧ ⌥ Space"
        }
    }

    fileprivate var keyCode: UInt32 { UInt32(kVK_Space) }

    fileprivate var modifiers: UInt32 {
        switch self {
        case .optionSpace: UInt32(optionKey)
        case .controlOptionSpace: UInt32(controlKey | optionKey)
        case .shiftOptionSpace: UInt32(shiftKey | optionKey)
        }
    }
}

/// Registers the push-to-talk shortcut and reports when it is pressed and released.
@MainActor
final class HotkeyMonitor {
    enum Event { case pressed, released }

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var isPressed = false
    private let onEvent: (Event) -> Void

    init(onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
    }

    /// Registers the shortcut, replacing the previous one. Returns `false` when another app
    /// holds it already.
    @discardableResult
    func register(_ preset: HotkeyPreset) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let identifier = EventHotKeyID(signature: OSType(0x4F75_746C), id: 1)  // "Outl"
        let status = RegisterEventHotKey(
            preset.keyCode, preset.modifiers, identifier, GetApplicationEventTarget(), 0, &hotKey)
        return status == noErr
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        if isPressed {
            isPressed = false
            onEvent(.released)
        }
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
}
