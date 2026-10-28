/// The ⌥ ⌘ push-to-talk chord of the macOS app, decided from the modifier flags of every key
/// event (ADR 0020, ADR 0021, ADR 0026).
///
/// ⌥ ⌘ held alone records. ⇧ or ⌃ joining it cancels at any time; another key cancels within
/// `shortcutWindow` of the press, since it makes a shortcut such as ⌥ ⌘ D. The second ⌘ or ⌥ —
/// the one on the other side of the keyboard — asks to paste the result when the user returns
/// to the field it was recorded in.
public struct OptionCommandChord: Sendable {
    public enum Event: Equatable, Sendable { case pressed, released, cancelled, pasteOnReturn }

    /// How long after ⌥ ⌘ another key still makes it a shortcut, such as ⌥ ⌘ D; after that the key
    /// is typed and the recording goes on (decided by the user, 2026-10-23).
    public static let shortcutWindow: Duration = .seconds(1)

    // The bits of `NSEvent.ModifierFlags`: the device-independent ones, and the device-dependent
    // ones that tell the left key from the right (`NX_DEVICELCMDKEYMASK` … in IOKit's
    // `IOLLEvent.h`). The device-independent ones do not change when the second key of a kind
    // joins.
    static let shift: UInt = 1 << 17
    static let control: UInt = 1 << 18
    static let option: UInt = 1 << 19
    static let command: UInt = 1 << 20
    static let bothCommands: UInt = 0x08 | 0x10
    static let bothOptions: UInt = 0x20 | 0x40

    public private(set) var isPressed = false
    /// While the chord is held: it turned out to be a different shortcut, so it does not start a
    /// recording again until ⌥ or ⌘ is released.
    private var spoiled = false
    private var pressedAt: ContinuousClock.Instant?
    private var pastesOnReturn = false

    public init() {}

    /// The flags of a `flagsChanged` event, as `NSEvent.ModifierFlags.rawValue`.
    public mutating func modifiersChanged(_ flags: UInt, at now: ContinuousClock.Instant)
        -> [Event]
    {
        let modifiers = flags & (Self.shift | Self.control | Self.option | Self.command)
        let chord = Self.option | Self.command
        if modifiers == chord {
            guard !spoiled else { return [] }
            var events: [Event] = []
            if !isPressed {
                isPressed = true
                pastesOnReturn = false
                pressedAt = now
                events.append(.pressed)
            }
            if !pastesOnReturn,
                flags & Self.bothCommands == Self.bothCommands
                    || flags & Self.bothOptions == Self.bothOptions
            {
                pastesOnReturn = true
                events.append(.pasteOnReturn)
            }
            return events
        }
        if modifiers & chord == chord {
            // ⇧ or ⌃ joined ⌥ ⌘: a shortcut, at any time.
            return cancel().map { [$0] } ?? []
        }
        spoiled = false
        guard isPressed else { return [] }
        isPressed = false
        return [.released]
    }

    /// A key other than a modifier went down.
    public mutating func keyPressed(at now: ContinuousClock.Instant) -> Event? {
        guard isPressed, let pressedAt, now - pressedAt < Self.shortcutWindow else { return nil }
        return cancel()
    }

    /// The chord is no longer watched: a held chord ends as released.
    public mutating func reset() -> Event? {
        spoiled = false
        guard isPressed else { return nil }
        isPressed = false
        return .released
    }

    private mutating func cancel() -> Event? {
        spoiled = true
        guard isPressed else { return nil }
        isPressed = false
        return .cancelled
    }
}
