/// The ⌥ ⌘ push-to-talk chord of the macOS app, decided from the modifier flags of every key
/// event (ADR 0020, ADR 0021).
///
/// ⌥ ⌘ held alone records. ⌃ joining it cancels at any time; ⇧ or another key cancels within
/// `shortcutWindow` of the press, since it makes a shortcut such as ⌥ ⌘ D, and is typed after it
/// (ADR 0029). The second ⌘ or ⌥ — the one on the other side of the keyboard — changes nothing
/// (ADR 0027).
public struct OptionCommandChord: Sendable {
    public enum Event: Equatable, Sendable { case pressed, released, cancelled }

    /// How long after ⌥ ⌘ another key still makes it a shortcut, such as ⌥ ⌘ D; after that the key
    /// is typed and the recording goes on (decided by the user, 2026-10-23).
    public static let shortcutWindow: Duration = .seconds(1)

    // The device-independent bits of `NSEvent.ModifierFlags`; they do not change when the second
    // key of a kind joins.
    static let shift: UInt = 1 << 17
    static let control: UInt = 1 << 18
    static let option: UInt = 1 << 19
    static let command: UInt = 1 << 20

    public private(set) var isPressed = false
    /// While the chord is held: it turned out to be a different shortcut, so it does not start a
    /// recording again until ⌥ or ⌘ is released.
    private var spoiled = false
    private var pressedAt: ContinuousClock.Instant?

    /// While the chord is held: from when keys and ⇧ are typed rather than make a shortcut, and
    /// reach the app without ⌥ and ⌘ (ADR 0029).
    public var typingStarts: ContinuousClock.Instant? {
        guard isPressed, let pressedAt else { return nil }
        return pressedAt + Self.shortcutWindow
    }

    public init() {}

    /// The flags of a `flagsChanged` event, as `NSEvent.ModifierFlags.rawValue`.
    public mutating func modifiersChanged(_ flags: UInt, at now: ContinuousClock.Instant)
        -> Event?
    {
        let modifiers = flags & (Self.shift | Self.control | Self.option | Self.command)
        let chord = Self.option | Self.command
        if modifiers == chord {
            guard !spoiled, !isPressed else { return nil }
            isPressed = true
            pressedAt = now
            return .pressed
        }
        if modifiers & chord == chord {
            // ⇧ joined ⌥ ⌘ to type a capital, once keys are typed.
            if modifiers == chord | Self.shift, let typingStarts, now >= typingStarts {
                return nil
            }
            // ⌃ at any time, or ⇧ early: a shortcut.
            return cancel()
        }
        spoiled = false
        guard isPressed else { return nil }
        isPressed = false
        return .released
    }

    /// A key other than a modifier went down.
    public mutating func keyPressed(at now: ContinuousClock.Instant) -> Event? {
        guard let typingStarts, now < typingStarts else { return nil }
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
