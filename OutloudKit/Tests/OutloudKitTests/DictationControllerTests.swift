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

@MainActor
struct DictationControllerTests {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "DictationControllerTests-\(UUID())")

    private func controller(
        cleanupEnabled: Bool = true, cleaner: (any Cleaning)?
    ) throws -> DictationController {
        let store = ModelStore(
            cache: HubCache(root: root.appending(path: "hub")),
            recordURL: root.appending(path: "record.json"))
        let settings = OutloudSettings(defaults: try #require(UserDefaults(suiteName: "\(UUID())")))
        settings.cleanupEnabled = cleanupEnabled
        settings.retentionPeriod = .nothing
        return DictationController(
            settings: settings, library: ModelLibrary(store: store), engines: Engines(store: store),
            history: HistoryStore(folder: root.appending(path: "history")), cleaner: { cleaner })
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
        let cleaner = StandInCleaner(answer: .success("Erste."), delay: .milliseconds(300))
        let controller = try controller(cleaner: cleaner)
        let first = Task { await controller.process(text: "erste") }
        try await Task.sleep(for: .milliseconds(50))
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
