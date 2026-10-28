/// Where each dictation on macOS is pasted, and when (ADR 0026, ADR 0027).
///
/// The app remembers the field focused when a recording started; this decides, from the field
/// focused at each check, when a result is pasted, when the user left a field, and when a result
/// is only copied. A result is pasted into its field only while that field is focused — not
/// another field of the same app, not the same field showing another conversation, not while
/// another app is in front. A dictation started in a field that already has one goes to the next
/// other field the user focuses. `Field` is the app's description of a focused field, equal when
/// it is the same field showing the same content.
public struct ReturnPaste<Field: Equatable> {
    public enum Action: Equatable {
        /// The user left the field of a dictation that is still processed or waits: it goes on
        /// out of sight, and the pill says once that it waits.
        case leftField(Ticket, Field)
        case paste(String)
        /// A dictation for the next field was done before the user focused one.
        case copy(String)
    }

    /// Names one dictation.
    public struct Ticket: Equatable, Sendable {
        fileprivate let number: Int
    }

    private enum Target: Equatable {
        case field(Field)
        /// The next field focused that is not this one.
        case nextField(after: Field)
    }

    private struct Dictation {
        let ticket: Ticket
        var target: Target
        var result: String?
        var left = false
    }

    private var dictations: [Dictation] = []
    private var count = 0

    public init() {}

    /// Whether a check of the focused field is needed.
    public var isActive: Bool { !dictations.isEmpty }

    /// A dictation was released in `field`. It goes into the next other field when a dictation
    /// for `field` is still processed or waits.
    public mutating func start(in field: Field) -> Ticket {
        count += 1
        let ticket = Ticket(number: count)
        let taken = dictations.contains { $0.target == .field(field) }
        dictations.append(
            Dictation(ticket: ticket, target: taken ? .nextField(after: field) : .field(field)))
        return ticket
    }

    /// Whether the dictation goes into the next field focused, so that its own is not shown.
    public func goesToNextField(_ ticket: Ticket) -> Bool {
        guard case .nextField = dictations.first(where: { $0.ticket == ticket })?.target else {
            return false
        }
        return true
    }

    /// The dictation ended without a result.
    public mutating func fail(_ ticket: Ticket) {
        dictations.removeAll { $0.ticket == ticket }
    }

    /// The dictation's result is ready; the next check pastes or copies it.
    public mutating func finish(_ ticket: Ticket, _ text: String) {
        guard let index = dictations.firstIndex(where: { $0.ticket == ticket }) else { return }
        dictations[index].result = text
    }

    /// The focused field at a check — `nil` when nothing takes text.
    public mutating func check(focused: Field?) -> [Action] {
        var actions: [Action] = []
        var done: [Ticket] = []
        for index in dictations.indices {
            var dictation = dictations[index]
            if case .nextField(let taken) = dictation.target, let focused, focused != taken {
                dictation.target = .field(focused)
            }
            switch dictation.target {
            case .nextField:
                if let result = dictation.result {
                    actions.append(.copy(result))
                    done.append(dictation.ticket)
                }
            case .field(let field):
                if focused == field {
                    if let result = dictation.result {
                        actions.append(.paste(result))
                        done.append(dictation.ticket)
                    }
                } else if !dictation.left {
                    dictation.left = true
                    actions.append(.leftField(dictation.ticket, field))
                }
            }
            dictations[index] = dictation
        }
        dictations.removeAll { done.contains($0.ticket) }
        return actions
    }
}
