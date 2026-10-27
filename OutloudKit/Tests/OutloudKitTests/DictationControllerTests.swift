import Foundation
import Testing

@testable import OutloudKit

/// Answers with a fixed text, or fails, in place of Apple's model.
private struct StandInCleaner: Cleaning {
    var answer: Result<String, CleanerError>
    var delay: Duration = .zero
    var tokens: Int?

    func clean(_ transcript: String) async throws -> String {
        if delay > .zero { try await Task.sleep(for: delay) }
        return try answer.get()
    }

    func tokenCount(for transcript: String) async -> Int? { tokens }
}

@MainActor
struct DictationControllerTests {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "DictationControllerTests-\(UUID())")

    private func controller(
        cleanupEnabled: Bool = true, cleaner: (any Cleaning)?,
        estimates: UserDefaults? = nil
    ) throws -> DictationController {
        let store = ModelStore(
            cache: HubCache(root: root.appending(path: "hub")),
            recordURL: root.appending(path: "record.json"))
        let settings = OutloudSettings(defaults: try #require(UserDefaults(suiteName: "\(UUID())")))
        settings.cleanupEnabled = cleanupEnabled
        settings.retentionPeriod = .nothing
        return DictationController(
            settings: settings, library: ModelLibrary(store: store), engines: Engines(store: store),
            history: HistoryStore(folder: root.appending(path: "history")), cleaner: { cleaner },
            estimates: try estimates ?? #require(UserDefaults(suiteName: "\(UUID())")))
    }

    @Test func movesTheCleanupBarByTimeAndLearnsTheDuration() async throws {
        let store = try #require(UserDefaults(suiteName: "\(UUID())"))
        let controller = try controller(
            cleaner: StandInCleaner(
                answer: .success("Hallo."), delay: .milliseconds(600), tokens: 40),
            estimates: store)
        let run = Task {
            await controller.finish(transcript: "äh hallo", audio: nil, showsProgress: true)
        }
        try await Task.sleep(for: .milliseconds(400))
        let halfway = try #require(controller.progress)
        #expect(halfway > 0 && halfway < PhaseProgress.onTime)
        _ = await run.value
        #expect(controller.progress == nil)
        let learned = DurationEstimate.cleanup(defaults: store).expectedDuration(units: 40)
        #expect(learned > .milliseconds(500) && learned < .seconds(2))
    }

    @Test func movesTheTranscriptionBarByTimeAndLearnsTheDuration() async throws {
        let store = try #require(UserDefaults(suiteName: "\(UUID())"))
        let controller = try controller(cleaner: nil, estimates: store)
        let estimate = DurationEstimate.transcription(modelID: "test", defaults: store)
        let run = Task {
            await controller.run(
                .transcribing, estimate: estimate, units: { 10 },
                work: { try? await Task.sleep(for: .milliseconds(600)) })
        }
        try await Task.sleep(for: .milliseconds(400))
        #expect(controller.state == .transcribing)
        let halfway = try #require(controller.progress)
        #expect(halfway > 0 && halfway < PhaseProgress.onTime)
        // 0.8 s expected for 10 s of audio before any run was measured.
        #expect(controller.secondsLeft == 1)
        await run.value
        #expect(controller.progress == nil)
        #expect(controller.secondsLeft == nil)
        let learned = estimate.expectedDuration(units: 10)
        #expect(learned > .milliseconds(500) && learned < .seconds(2))
    }

    @Test func cleansUpWithTheModel() async throws {
        let cleaner = StandInCleaner(answer: .success("Hallo zusammen."))
        let outcome = try #require(
            await controller(cleaner: cleaner).process(text: "äh hallo zusammen"))
        #expect(outcome.cleanup == .cleaned("Hallo zusammen."))
    }

    @Test func handsOverTheTranscriptWhenTheModelRefuses() async throws {
        let cleaner = StandInCleaner(answer: .failure(.refused("rateLimited")))
        let outcome = try #require(
            await controller(cleaner: cleaner).process(text: "äh hallo zusammen"))
        #expect(outcome.cleanup == .failed)
        #expect(outcome.result == "äh hallo zusammen")
    }

    @Test func handsOverTheTranscriptWhenCleanupIsUnavailable() async throws {
        let outcome = try #require(await controller(cleaner: nil).process(text: "äh hallo"))
        #expect(outcome.cleanup == .off)
    }

    @Test func refusesASecondDictationWhileOneIsRunning() async throws {
        let cleaner = StandInCleaner(answer: .success("Erste."), delay: .milliseconds(500))
        let controller = try controller(cleaner: cleaner)
        let first = Task { await controller.process(text: "erste") }
        let deadline = ContinuousClock.now + .seconds(5)
        while controller.state != .cleaning, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(controller.state == .cleaning)
        #expect(await controller.process(text: "zweite") == nil)
        #expect(await first.value?.cleaned == "Erste.")
    }

    @Test func leavesTheTranscriptAloneWhenCleanupIsOff() async throws {
        let cleaner = StandInCleaner(answer: .success("Hallo."))
        let outcome = try #require(
            await controller(cleanupEnabled: false, cleaner: cleaner).process(text: "äh hallo"))
        #expect(outcome.cleanup == .off)
    }
}
