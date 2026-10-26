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

    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    @Test func guessesBeforeAnythingWasMeasured() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        #expect(timings.expectedDuration(tokens: nil) == CleanupTimings.initialDuration)
        let guess = CleanupTimings.initialStart + 100 * CleanupTimings.initialSecondsPerToken
        #expect(abs(seconds(timings.expectedDuration(tokens: 100)) - guess) < 0.001)
    }

    @Test func learnsTheStartAndTheTimePerToken() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        for tokens in [20, 50, 80, 120, 200] {
            timings.record(.seconds(0.5 + 0.01 * Double(tokens)), tokens: tokens)
        }
        #expect(abs(seconds(timings.expectedDuration(tokens: 300)) - 3.5) < 0.001)
        #expect(abs(seconds(timings.expectedDuration(tokens: 30)) - 0.8) < 0.001)
    }

    @Test func barelyMovesForOneSlowCleanup() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        for tokens in [20, 50, 80, 120, 200] {
            timings.record(.seconds(0.5 + 0.01 * Double(tokens)), tokens: tokens)
        }
        timings.record(.seconds(6), tokens: 60)
        #expect(abs(seconds(timings.expectedDuration(tokens: 60)) - 1.1) < 0.15)
    }

    @Test func takesTheTimePerTokenWhileOnlyOneLengthWasMeasured() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        timings.record(.seconds(1), tokens: 50)
        timings.record(.seconds(1.2), tokens: 50)
        #expect(abs(seconds(timings.expectedDuration(tokens: 100)) - 2.2) < 0.001)
        #expect(abs(seconds(timings.expectedDuration(tokens: nil)) - 1.1) < 0.001)
    }

    @Test func forgetsCleanupsBeyondTheWindow() throws {
        let timings = CleanupTimings(defaults: try defaults(), prompt: "a")
        for _ in 0..<CleanupTimings.window { timings.record(.seconds(4), tokens: 50) }
        for _ in 0..<(CleanupTimings.window / 2 + 1) { timings.record(.seconds(1), tokens: 50) }
        #expect(timings.expectedDuration(tokens: nil) == .seconds(1))
    }

    @Test func startsAnewWhenThePromptChanged() throws {
        let store = try defaults()
        CleanupTimings(defaults: store, prompt: "old").record(.seconds(4), tokens: 50)
        let timings = CleanupTimings(defaults: store, prompt: "new")
        #expect(timings.expectedDuration(tokens: nil) == CleanupTimings.initialDuration)
        timings.record(.seconds(1), tokens: 50)
        #expect(timings.expectedDuration(tokens: nil) == .seconds(1))
    }

    @Test func dropsWhatEarlierReleasesKept() throws {
        let store = try defaults()
        store.set(1.97, forKey: "cleanupSeconds")
        store.set([1.2, 1.3], forKey: "cleanupDurations")
        CleanupTimings(defaults: store, prompt: "a").record(.seconds(1), tokens: 40)
        #expect(store.object(forKey: "cleanupSeconds") == nil)
        #expect(store.object(forKey: "cleanupDurations") == nil)
    }

    @Test func fingerprintsThePromptStably() {
        #expect(CleanupPrompt.fingerprint.count == 64)
        #expect(CleanupPrompt.fingerprint == CleanupPrompt.fingerprint)
    }
}
