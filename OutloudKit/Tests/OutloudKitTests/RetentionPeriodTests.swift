import Foundation
import Testing

@testable import OutloudKit

struct RetentionPeriodTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func theDefaultIsOneDay() {
        #expect(RetentionPeriod.default == .oneDay)
    }

    @Test func offersExactlyThePeriodsOfTheSpecification() {
        #expect(
            RetentionPeriod.allCases == [
                .nothing, .oneDay, .threeDays, .tenDays, .thirtyDays, .threeMonths, .unlimited,
            ])
    }

    @Test func nothingExpiresAtCreation() {
        let creation = date(2026, 10, 22)
        #expect(
            RetentionPeriod.nothing.expiry(ofResultCreatedAt: creation, in: calendar) == creation)
    }

    @Test func unlimitedNeverExpires() {
        #expect(
            RetentionPeriod.unlimited.expiry(ofResultCreatedAt: date(2026, 10, 22), in: calendar)
                == nil)
    }

    @Test(arguments: [
        (RetentionPeriod.oneDay, 10, 23),
        (.threeDays, 10, 25),
        (.tenDays, 11, 1),
        (.thirtyDays, 11, 21),
    ])
    func dayPeriodsAddCalendarDays(period: RetentionPeriod, month: Int, day: Int) {
        let expiry = period.expiry(ofResultCreatedAt: date(2026, 10, 22), in: calendar)
        #expect(expiry == date(2026, month, day))
    }

    @Test func oneDayKeepsTheTimeOfDayAcrossTheEndOfDaylightSaving() {
        // 25 October 2026 has 25 hours in Berlin.
        let expiry = RetentionPeriod.oneDay.expiry(
            ofResultCreatedAt: date(2026, 10, 24, hour: 12), in: calendar)
        #expect(expiry == date(2026, 10, 25, hour: 12))
    }

    @Test func threeMonthsAddCalendarMonthsAndClampToTheMonthsEnd() {
        let expiry = RetentionPeriod.threeMonths.expiry(
            ofResultCreatedAt: date(2026, 11, 30), in: calendar)
        #expect(expiry == date(2027, 2, 28))
    }
}
