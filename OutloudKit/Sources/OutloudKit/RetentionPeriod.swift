import Foundation

/// How long Outloud keeps a result in the history (`docs/SPEC.md` §"History").
public enum RetentionPeriod: String, CaseIterable, Codable, Sendable {
    case nothing
    case oneDay
    case threeDays
    case tenDays
    case thirtyDays
    case threeMonths
    case unlimited

    /// The period in effect until the user chooses another one.
    public static let `default`: RetentionPeriod = .oneDay

    /// The moment a result created at `creation` expires, or `nil` when it is kept without limit.
    ///
    /// With `.nothing` a result expires the moment it is created, so it is never kept.
    public func expiry(ofResultCreatedAt creation: Date, in calendar: Calendar) -> Date? {
        let offset: DateComponents
        switch self {
        case .nothing: return creation
        case .oneDay: offset = DateComponents(day: 1)
        case .threeDays: offset = DateComponents(day: 3)
        case .tenDays: offset = DateComponents(day: 10)
        case .thirtyDays: offset = DateComponents(day: 30)
        case .threeMonths: offset = DateComponents(month: 3)
        case .unlimited: return nil
        }
        return calendar.date(byAdding: offset, to: creation)
    }
}
