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

    @Test func submitsOnlyInTheAppsTheUserListed() throws {
        let defaults = try #require(UserDefaults(suiteName: "OutloudSettingsTests-\(UUID())"))
        let settings = OutloudSettings(defaults: defaults)
        #expect(settings.submitAfterPasteApps.isEmpty)
        #expect(!settings.submitsAfterPaste(in: "com.anthropic.claudefordesktop"))
        settings.submitAfterPasteApps = ["com.anthropic.claudefordesktop"]

        let reloaded = OutloudSettings(defaults: defaults)
        #expect(reloaded.submitsAfterPaste(in: "com.anthropic.claudefordesktop"))
        #expect(!reloaded.submitsAfterPaste(in: "com.apple.MobileSMS"))
        #expect(!reloaded.submitsAfterPaste(in: "com.anthropic"))
        #expect(!reloaded.submitsAfterPaste(in: ""))
        #expect(!reloaded.submitsAfterPaste(in: nil))
    }
}
