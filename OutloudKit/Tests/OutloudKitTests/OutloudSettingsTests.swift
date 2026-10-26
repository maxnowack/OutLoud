import Foundation
import Testing

@testable import OutloudKit

@MainActor
struct OutloudSettingsTests {
    @Test func pausesPlaybackUnlessTheUserTurnedItOff() throws {
        let defaults = try #require(UserDefaults(suiteName: "OutloudSettingsTests-\(UUID())"))
        #expect(OutloudSettings(defaults: defaults).pausesPlayback)
        OutloudSettings(defaults: defaults).pausesPlayback = false
        #expect(!OutloudSettings(defaults: defaults).pausesPlayback)
    }
}
