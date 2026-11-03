import Foundation
import Testing

@testable import OutloudKit

/// Answers with a fixed text, or fails, in place of Apple's model.
private struct StandInCleaner: Cleaning {
    var answer: Result<String, CleanerError>
    var delay: Duration = .zero

    func clean(_ transcript: String) async throws -> String {
        if delay > .zero { try await Task.sleep(for: delay) }
        return try answer.get()
    }
}

/// Reads a fixed text from any lips and keeps what it is given.
@MainActor
private final class StandInLipReader: LipReading {
    var text = ""
    var kept: [(frames: MouthFrames, transcript: String, language: String)] = []
    func startWatching() -> Bool { true }
    func stopWatching() async -> MouthFrames? { nil }
    func read(_ frames: MouthFrames) async throws -> String { text }
    func keep(_ frames: MouthFrames, transcript: String, language: String) async {
        kept.append((frames, transcript, language))
    }
}

@MainActor
struct DictationControllerTests {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "DictationControllerTests-\(UUID())")

    private func controller(
        cleanupEnabled: Bool = true, cleaner: (any Cleaning)?,
        estimates: UserDefaults? = nil, lipReading: LipReadingMode = .off,
        settings given: OutloudSettings? = nil
    ) throws -> DictationController {
        let store = ModelStore(
            cache: HubCache(root: root.appending(path: "hub")),
            recordURL: root.appending(path: "record.json"))
        let settings =
            try given ?? OutloudSettings(defaults: #require(UserDefaults(suiteName: "\(UUID())")))
        settings.cleanupEnabled = cleanupEnabled
        settings.retentionPeriod = .nothing
        settings.lipReading = lipReading
        return DictationController(
            settings: settings, library: ModelLibrary(store: store), engines: Engines(store: store),
            history: HistoryStore(folder: root.appending(path: "history")), cleaner: { cleaner },
            estimates: try estimates ?? #require(UserDefaults(suiteName: "\(UUID())")))
    }

    @Test func movesTheCleanupBarByTimeAndLearnsTheDuration() async throws {
        let store = try #require(UserDefaults(suiteName: "\(UUID())"))
        let controller = try controller(
            cleaner: StandInCleaner(answer: .success("Hallo."), delay: .milliseconds(600)),
            estimates: store)
        let run = Task {
            await controller.finish(transcript: "äh hallo", audio: nil, showsProgress: true)
        }
        try await Task.sleep(for: .milliseconds(400))
        let halfway = try #require(controller.progress)
        #expect(halfway > 0 && halfway < PhaseProgress.onTime)
        // 1.1 s expected for the 8 characters before any run was measured.
        #expect(controller.secondsLeft == 1)
        _ = await run.value
        #expect(controller.progress == nil)
        let learned = DurationEstimate.cleanup(defaults: store).expectedDuration(units: 8)
        #expect(learned > .milliseconds(500) && learned < .seconds(2))
    }

    @Test func movesTheTranscriptionBarByTimeAndLearnsTheDuration() async throws {
        let store = try #require(UserDefaults(suiteName: "\(UUID())"))
        let controller = try controller(cleaner: nil, estimates: store)
        let estimate = DurationEstimate.transcription(modelID: "test", defaults: store)
        let run = Task {
            await controller.run(
                .transcribing, estimate: estimate, units: 10,
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

    @Test func readsTheLipsInTheSilentModeWithoutTheTranscriptionModel() async throws {
        let lips = StandInLipReader()
        lips.text = "hello there"
        let dictation = try controller(
            cleaner: StandInCleaner(answer: .success("Hello there.")), lipReading: .silent)
        dictation.lipReading = lips
        let frames = MouthFrames(pixels: [UInt8](repeating: 0, count: 96 * 96), frames: 1)
        let outcome = try #require(await dictation.process(samples: [0, 0], lips: frames))
        #expect(outcome.transcript == "hello there")
        #expect(outcome.result == "Hello there.")
        #expect(lips.kept.isEmpty)
    }

    @Test func takesTheLanguageOfWhatIsSaidAloudAndKeepsTheLipsInIt() async throws {
        let settings = OutloudSettings(defaults: try #require(UserDefaults(suiteName: "\(UUID())")))
        settings.lipReadingLanguage = "en"
        settings.learnsFromDictations = true
        let lips = StandInLipReader()
        let dictation = try controller(cleaner: nil, settings: settings)
        dictation.lipReading = lips
        let frames = MouthFrames(pixels: [UInt8](repeating: 0, count: 96 * 96), frames: 1)

        await dictation.heard("Okay.", lips: Task { frames })
        #expect(settings.lipReadingLanguage == "en")
        #expect(lips.kept.isEmpty)

        await dictation.heard("Bitte schick mir den Bericht bis Freitag.", lips: Task { frames })
        #expect(settings.lipReadingLanguage == "de")
        #expect(lips.kept.map(\.language) == ["de"])

        settings.learnsFromDictations = false
        await dictation.heard("Please send me the report by Friday.", lips: Task { frames })
        #expect(settings.lipReadingLanguage == "en")
        #expect(lips.kept.count == 1)
    }

    @Test func reportsNothingRecognisedWhenNoFaceWasSeen() async throws {
        let dictation = try controller(cleaner: nil, lipReading: .silent)
        dictation.lipReading = StandInLipReader()
        #expect(await dictation.process(samples: [0], lips: nil) == nil)
        #expect(dictation.state == .failed(.nothingRecognised))
    }

    @Test func watchesTheLipsToReadThemOrToLearnFromThem() throws {
        let settings = OutloudSettings(defaults: try #require(UserDefaults(suiteName: "\(UUID())")))
        #expect(!settings.learnsFromDictations)
        #expect(!DictationController.watchesLips(settings))
        settings.learnsFromDictations = true
        #expect(DictationController.watchesLips(settings))
        settings.learnsFromDictations = false
        settings.lipReading = .whenSilent
        #expect(DictationController.watchesLips(settings))
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

    @Test func processesABackgroundDictationWithoutTouchingTheState() async throws {
        let controller = try controller(cleaner: StandInCleaner(answer: .success("Hallo.")))
        let outcome = await controller.processInBackground(text: "äh hallo")
        #expect(outcome?.cleaned == "Hallo.")
        #expect(controller.state == .idle)
        #expect(controller.progress == nil)
    }

    @Test func letsTheNextDictationStartWhileOneIsProcessedInTheBackground() async throws {
        let cleaner = StandInCleaner(answer: .success("Fertig."), delay: .milliseconds(300))
        let controller = try controller(cleaner: cleaner)
        let start = ContinuousClock.now
        let background = Task { await controller.processInBackground(text: "erste") }
        try await Task.sleep(for: .milliseconds(50))
        #expect(controller.state == .idle)
        let foreground = try #require(await controller.process(text: "zweite"))
        // One after another, not side by side.
        #expect(ContinuousClock.now - start >= .milliseconds(600))
        #expect(await background.value?.cleaned == "Fertig.")
        #expect(controller.state == .finished(foreground))
    }

    @Test func handsTheDictationInSightToTheBackgroundMidway() async throws {
        let cleaner = StandInCleaner(answer: .success("Erste."), delay: .milliseconds(300))
        let controller = try controller(cleaner: cleaner)
        let first = Task { await controller.process(text: "erste") }
        let deadline = ContinuousClock.now + .seconds(5)
        while controller.state != .cleaning, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        controller.continueInBackground()
        #expect(controller.state == .idle)
        #expect(controller.progress == nil)
        // The next dictation starts at once and is the one the state follows.
        let second = try #require(await controller.process(text: "zweite"))
        #expect(await first.value?.cleaned == "Erste.")
        #expect(controller.state == .finished(second))
    }

    @Test func leavesTheTranscriptAloneWhenCleanupIsOff() async throws {
        let cleaner = StandInCleaner(answer: .success("Hallo."))
        let outcome = try #require(
            await controller(cleanupEnabled: false, cleaner: cleaner).process(text: "äh hallo"))
        #expect(outcome.cleanup == .off)
    }
}
