import Foundation
import Testing

@testable import OutloudKit

struct CleanupProgressTests {
    @Test func fillsEvenlyUntilTheUsualDuration() {
        let expected = Duration.seconds(2)
        #expect(CleanupProgress.value(elapsed: .zero, expected: expected) == 0)
        #expect(CleanupProgress.value(elapsed: .seconds(1), expected: expected) == 0.45)
        #expect(
            CleanupProgress.value(elapsed: expected, expected: expected) == CleanupProgress.onTime)
    }

    @Test func creepsOnBelowTheCeilingWhenItTakesLonger() {
        let expected = Duration.seconds(2)
        let values = stride(from: 2.5, through: 12, by: 0.5).map {
            CleanupProgress.value(elapsed: .seconds($0), expected: expected)
        }
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 < $1 })
        #expect(values.allSatisfy { $0 > CleanupProgress.onTime && $0 < CleanupProgress.ceiling })
    }
}

@MainActor
struct CleanupTimingsTests {
    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "CleanupTimingsTests-\(UUID())"))
    }

    @Test func guessesBeforeAnythingWasMeasured() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        #expect(timings.expectedDuration == CleanupTimings.initialDuration)
    }

    @Test func takesTheMedianSoThatASlowCleanupDoesNotMoveIt() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        timings.record(.seconds(2))
        #expect(timings.expectedDuration == .seconds(2))
        timings.record(.seconds(1))
        #expect(timings.expectedDuration == .seconds(1.5))
        for seconds in [1.2, 1.3, 5.0] { timings.record(.seconds(seconds)) }
        #expect(timings.expectedDuration == .seconds(1.3))
    }

    @Test func forgetsDurationsBeyondTheWindow() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        for _ in 0..<CleanupTimings.window { timings.record(.seconds(4)) }
        for _ in 0..<(CleanupTimings.window / 2 + 1) { timings.record(.seconds(1)) }
        #expect(timings.expectedDuration == .seconds(1))
    }

    @Test func dropsTheMovingAverageOfTheFirstRelease() throws {
        let store = try defaults()
        store.set(1.97, forKey: "cleanupSeconds")
        CleanupTimings(defaults: store, prompt: "a").record(.seconds(1))
        #expect(store.object(forKey: "cleanupSeconds") == nil)
    }

    @Test func startsAnewWhenThePromptChanged() throws {
        let store = try defaults()
        CleanupTimings(defaults: store, prompt: "old").record(.seconds(4))
        let timings = CleanupTimings(defaults: store, prompt: "new")
        #expect(timings.expectedDuration == CleanupTimings.initialDuration)
        timings.record(.seconds(1))
        #expect(timings.expectedDuration == .seconds(1))
    }

    @Test func fingerprintsThePromptStably() {
        #expect(CleanupPrompt.fingerprint.count == 64)
        #expect(CleanupPrompt.fingerprint == CleanupPrompt.fingerprint)
    }
}
