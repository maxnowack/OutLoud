import Foundation
import Testing

@testable import OutloudKit

struct DiagnosticsLogTests {
    let file = FileManager.default.temporaryDirectory.appending(
        path: "DiagnosticsLogTests-\(UUID())/diagnostics.jsonl")
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func keepsOneLineOfJSONPerEntryTheNewestLast() async throws {
        let log = DiagnosticsLog(file: file)
        await log.record(.launch(at: date))
        await log.record(
            .start(at: date, trigger: .shortcut, after: .milliseconds(142), state: .recording))

        let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
        #expect(
            lines == [
                #"{"at":"2027-01-15T08:00:00Z","kind":"launch"}"#,
                #"{"at":"2027-01-15T08:00:00Z","kind":"start","milliseconds":142,"outcome":"recording","trigger":"shortcut"}"#,
            ])
        #expect(await log.entries().map(\.kind) == [.launch, .start])
    }

    @Test func keepsOnlyTheLastEntries() async {
        let log = DiagnosticsLog(file: file, limit: 3)
        for second in 0..<5 {
            await log.record(.launch(at: date + TimeInterval(second)))
        }
        #expect(await log.entries().map(\.at) == (2..<5).map { date + TimeInterval($0) })
    }

    @Test func namesWhyAStartDidNotRecord() {
        func outcome(_ state: DictationState) -> String? {
            DiagnosticsLog.Entry.start(at: date, trigger: .app, after: .zero, state: state).outcome
        }
        #expect(outcome(.cleaning) == "busy")
        #expect(outcome(.failed(.modelsMissing)) == "modelsMissing")
        #expect(
            outcome(.failed(.recordingFailed("com.apple.coreaudio.avfaudio error 2003329396")))
                == "recordingFailed: com.apple.coreaudio.avfaudio error 2003329396")
        // A finished dictation's state holds its text, which never goes into the log.
        #expect(outcome(.finished(DictationOutcome(transcript: "geheim"))) == "notStarted")
    }

    @Test func namesWhatBecameOfTheCleanupWithoutTheText() {
        func outcome(_ outcome: DictationOutcome?, _ state: DictationState = .idle) -> String? {
            DiagnosticsLog.Entry.end(
                at: date, trigger: .shortcut, after: .seconds(21), outcome: outcome, state: state
            ).outcome
        }
        #expect(outcome(DictationOutcome(transcript: "a", cleanup: .cleaned("A."))) == "cleaned")
        #expect(outcome(DictationOutcome(transcript: "a", cleanup: .failed)) == "cleanupFailed")
        #expect(outcome(DictationOutcome(transcript: "a")) == "cleanupOff")
        #expect(outcome(nil, .failed(.nothingRecognised)) == "nothingRecognised")
        #expect(outcome(nil) == "noResult")
    }

    @Test func roundsTheDurationToMilliseconds() {
        let entry = DiagnosticsLog.Entry.end(
            at: date, trigger: .app, after: .microseconds(20_000_600), outcome: nil, state: .idle)
        #expect(entry.milliseconds == 20_001)
    }

    @Test func dropsAWriteThatFails() async {
        // A file where its folder should be: the folder cannot be made.
        let blocked = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: blocked.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: blocked.path, contents: Data())
        let log = DiagnosticsLog(file: file)
        await log.record(.launch(at: date))
        #expect(await log.entries().isEmpty)
    }
}
