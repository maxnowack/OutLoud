/// When a dictation pasted on return goes into its field (ADR 0026).
///
/// The app remembers the field focused when the recording started; this decides, from the field
/// focused at each check, when the result is pasted and when the pill says that it waits. The
/// field is pasted into only when it is focused again — not another field of the same app, not
/// the same field showing another conversation, not while another app is in front. `Field` is
/// the app's description of a focused field, equal when it is the same field showing the same
/// content.
public struct ReturnPaste<Field: Equatable> {
    public enum Action: Equatable {
        /// The user left the field: the pill says once that the result waits, then goes.
        case showWaitingNotice
        case paste(String)
    }

    /// Names one dictation, so that an older one that finishes late leaves the newer alone.
    public struct Ticket: Equatable, Sendable {
        fileprivate let number: Int
    }

    /// The field of the dictation still transcribed or cleaned up.
    public private(set) var processed: Field?
    /// The finished result that waits for its field.
    public private(set) var waiting: (text: String, field: Field)?
    private var noticeShown = false
    private var current = Ticket(number: 0)

    public init() {}

    /// Whether a check of the focused field is needed.
    public var isActive: Bool { processed != nil || waiting != nil }

    /// A dictation in this mode was released in `field`. The newest dictation replaces one that
    /// still waits or is still processed: its result is dropped (it stays in the history).
    public mutating func start(in field: Field) -> Ticket {
        current = Ticket(number: current.number + 1)
        processed = field
        waiting = nil
        noticeShown = false
        return current
    }

    /// The dictation ended without a result.
    public mutating func fail(_ ticket: Ticket) {
        guard ticket == current else { return }
        processed = nil
    }

    /// The dictation's result is ready, with `focused` the field focused now — `nil` when
    /// another app is in front or nothing takes text.
    public mutating func finish(_ ticket: Ticket, _ text: String, focused: Field?) -> Action? {
        guard ticket == current, let field = processed else { return nil }
        processed = nil
        if focused == field { return .paste(text) }
        waiting = (text, field)
        guard !noticeShown else { return nil }
        noticeShown = true
        return .showWaitingNotice
    }

    /// The focused field at a check — `nil` when another app is in front or nothing takes text.
    public mutating func check(focused: Field?) -> Action? {
        if let waiting, focused == waiting.field {
            self.waiting = nil
            return .paste(waiting.text)
        }
        if let processed, focused != processed, !noticeShown {
            noticeShown = true
            return .showWaitingNotice
        }
        return nil
    }
}
