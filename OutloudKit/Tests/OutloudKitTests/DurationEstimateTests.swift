import Foundation
import Testing

@testable import OutloudKit

struct PhaseProgressTests {
    @Test func fillsEvenlyUntilTheUsualDuration() {
        let expected = Duration.seconds(2)
        #expect(PhaseProgress.value(elapsed: .zero, expected: expected) == 0)
        #expect(PhaseProgress.value(elapsed: .seconds(1), expected: expected) == 0.45)
        #expect(
            PhaseProgress.value(elapsed: expected, expected: expected) == PhaseProgress.onTime)
    }

    @Test func creepsOnBelowTheCeilingWhenItTakesLonger() {
        let expected = Duration.seconds(2)
        let values = stride(from: 2.5, through: 12, by: 0.5).map {
            PhaseProgress.value(elapsed: .seconds($0), expected: expected)
        }
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 < $1 })
        #expect(values.allSatisfy { $0 > PhaseProgress.onTime && $0 < PhaseProgress.ceiling })
    }

    @Test func countsDownWholeSecondsUntilTheUsualDuration() {
        let expected = Duration.seconds(2)
        let left = [0, 0.5, 1.2, 1.9, 2, 3].map {
            PhaseProgress.secondsLeft(elapsed: .seconds($0), expected: expected)
        }
        #expect(left == [2, 2, 1, 1, nil, nil])
    }
}

@MainActor
struct DurationEstimateTests {
    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "DurationEstimateTests-\(UUID())"))
    }

    private func cleanup(_ defaults: UserDefaults, _ prompt: String) -> DurationEstimate {
        DurationEstimate(.cleanup, fingerprint: prompt, defaults: defaults)
    }

    private func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    private let guess =
        DurationEstimate.Step.cleanup.initialStart + 100
        * DurationEstimate.Step.cleanup.initialPerUnit

    @Test func guessesBeforeAnythingWasMeasured() throws {
        let estimate = cleanup(try defaults(), "a")
        #expect(abs(seconds(estimate.expectedDuration(units: 100)) - guess) < 0.001)
    }

    @Test func learnsTheStartAndTheTimePerCharacter() throws {
        let estimate = cleanup(try defaults(), "a")
        for characters in [20, 50, 80, 120, 200] {
            estimate.record(.seconds(0.5 + 0.01 * Double(characters)), units: Double(characters))
        }
        #expect(abs(seconds(estimate.expectedDuration(units: 300)) - 3.5) < 0.001)
        #expect(abs(seconds(estimate.expectedDuration(units: 30)) - 0.8) < 0.001)
    }

    @Test func barelyMovesForOneSlowCleanup() throws {
        let estimate = cleanup(try defaults(), "a")
        for characters in [20, 50, 80, 120, 200] {
            estimate.record(.seconds(0.5 + 0.01 * Double(characters)), units: Double(characters))
        }
        estimate.record(.seconds(6), units: Double(60))
        #expect(abs(seconds(estimate.expectedDuration(units: 60)) - 1.1) < 0.15)
    }

    @Test func learnsOnlyTheStartWhileOneLengthWasMeasured() throws {
        let estimate = cleanup(try defaults(), "a")
        estimate.record(.seconds(1), units: Double(50))
        estimate.record(.seconds(1.2), units: Double(50))
        let perUnit = DurationEstimate.Step.cleanup.initialPerUnit
        #expect(abs(seconds(estimate.expectedDuration(units: 100)) - (1.1 + 50 * perUnit)) < 0.001)
    }

    @Test func doesNotScaleAShortTextsDurationUpToALongOne() throws {
        let estimate = cleanup(try defaults(), "a")
        estimate.record(.seconds(2.2), units: Double(7))
        #expect(estimate.expectedDuration(units: 228) < .seconds(5))
    }

    @Test func takesNoTimePerCharacterFromTwoLengthsCloseTogether() throws {
        let estimate = cleanup(try defaults(), "a")
        estimate.record(.seconds(2), units: Double(30))
        estimate.record(.seconds(2.8), units: Double(40))
        #expect(estimate.expectedDuration(units: 300) < .seconds(6))
    }

    @Test func forgetsCleanupsBeyondTheWindow() throws {
        let estimate = cleanup(try defaults(), "a")
        for _ in 0..<DurationEstimate.window { estimate.record(.seconds(4), units: Double(50)) }
        for _ in 0..<(DurationEstimate.window / 2 + 1) {
            estimate.record(.seconds(1), units: Double(50))
        }
        #expect(abs(seconds(estimate.expectedDuration(units: 50)) - 1) < 0.001)
    }

    @Test func startsAnewWhenThePromptChanged() throws {
        let store = try defaults()
        cleanup(store, "old").record(.seconds(4), units: Double(100))
        let estimate = cleanup(store, "new")
        #expect(abs(seconds(estimate.expectedDuration(units: 100)) - guess) < 0.001)
        estimate.record(.seconds(1), units: Double(100))
        #expect(abs(seconds(estimate.expectedDuration(units: 100)) - 1) < 0.001)
    }

    @Test func dropsWhatEarlierReleasesKept() throws {
        let store = try defaults()
        store.set(1.97, forKey: "cleanupSeconds")
        store.set([1.2, 1.3], forKey: "cleanupDurations")
        store.set([[19.0, 4.0]], forKey: "cleanupSamples")
        let estimate = cleanup(store, "a")
        #expect(abs(seconds(estimate.expectedDuration(units: 100)) - guess) < 0.001)
        estimate.record(.seconds(1), units: Double(40))
        for key in ["cleanupSeconds", "cleanupDurations", "cleanupSamples"] {
            #expect(store.object(forKey: key) == nil)
        }
    }

    @Test func learnsTheTranscriptionPerModelApartFromTheCleanup() throws {
        let store = try defaults()
        let parakeet = DurationEstimate.transcription(modelID: "parakeet", defaults: store)
        for audio in [2.0, 5, 10] { parakeet.record(.seconds(0.2 + 0.03 * audio), units: audio) }
        #expect(abs(seconds(parakeet.expectedDuration(units: 20)) - 0.8) < 0.001)
        #expect(abs(seconds(cleanup(store, "a").expectedDuration(units: 100)) - guess) < 0.001)
        let other = DurationEstimate.transcription(modelID: "other", defaults: store)
        let transcriptionGuess =
            DurationEstimate.Step.transcription.initialStart + 20
            * DurationEstimate.Step.transcription.initialPerUnit
        #expect(abs(seconds(other.expectedDuration(units: 20)) - transcriptionGuess) < 0.001)
    }

    @Test func fingerprintsThePromptStably() {
        #expect(CleanupPrompt.fingerprint.count == 64)
        #expect(CleanupPrompt.fingerprint == CleanupPrompt.fingerprint)
    }
}
