import Foundation
import Testing

@testable import OutloudKit

struct HistoryStoreTests {
    let folder = FileManager.default.temporaryDirectory.appending(
        path: "HistoryStoreTests-\(UUID())")
    let calendar = Calendar(identifier: .gregorian)
    let created = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func keepsTranscriptAudioAndCleanedVersion() async throws {
        let store = HistoryStore(folder: folder)
        let samples: [Float] = [0, 0.5, -0.5, 1, -1]
        let entry = try #require(
            try await store.add(
                transcript: "äh hallo", cleaned: "Hallo.", audio: samples, at: created,
                period: .oneDay))

        #expect(entry.result == "Hallo.")
        #expect(await store.all() == [entry])
        let (read, rate) = try WAVFile.read(await store.audioURL(of: entry))
        #expect(rate == 16_000)
        #expect(read.count == samples.count)
        #expect(zip(read, samples).allSatisfy { abs($0 - $1) < 0.001 })
    }

    @Test func keepsNothingWhenThePeriodIsNothing() async throws {
        let store = HistoryStore(folder: folder)
        let entry = try await store.add(
            transcript: "a", cleaned: nil, audio: [0], at: created, period: .nothing)
        #expect(entry == nil)
        #expect(await store.all().isEmpty)
        #expect(FileManager.default.fileExists(atPath: folder.path) == false)
    }

    @Test func keepsNoAudioForSystemDictation() async throws {
        let store = HistoryStore(folder: folder)
        let entry = try #require(
            try await store.add(
                transcript: "typed", cleaned: nil, audio: nil, at: created, period: .oneDay))
        #expect(entry.hasAudio == false)
        #expect(
            FileManager.default.fileExists(atPath: await store.audioURL(of: entry).path) == false)
    }

    @Test func survivesARestart() async throws {
        let entry = try #require(
            try await HistoryStore(folder: folder).add(
                transcript: "t", cleaned: "c", audio: nil, at: created, period: .unlimited))
        #expect(await HistoryStore(folder: folder).all() == [entry])
    }

    @Test func removesEntriesWhosePeriodEndedWithTheirAudio() async throws {
        let store = HistoryStore(folder: folder)
        let old = try #require(
            try await store.add(
                transcript: "old", cleaned: nil, audio: [0], at: created, period: .oneDay))
        let new = try #require(
            try await store.add(
                transcript: "new", cleaned: nil, audio: [0], at: created.addingTimeInterval(86_000),
                period: .oneDay))

        try await store.removeExpired(
            now: created.addingTimeInterval(86_400), period: .oneDay, calendar: calendar)

        #expect(await store.all() == [new])
        #expect(FileManager.default.fileExists(atPath: await store.audioURL(of: old).path) == false)
    }

    @Test func aShorterPeriodAppliesToEntriesAlreadyKept() async throws {
        let store = HistoryStore(folder: folder)
        try await store.add(
            transcript: "t", cleaned: nil, audio: nil, at: created, period: .thirtyDays)
        try await store.removeExpired(now: created, period: .nothing, calendar: calendar)
        #expect(await store.all().isEmpty)
    }

    @Test func unlimitedKeepsEverything() async throws {
        let store = HistoryStore(folder: folder)
        try await store.add(
            transcript: "t", cleaned: nil, audio: nil, at: created, period: .unlimited)
        try await store.removeExpired(
            now: created.addingTimeInterval(10 * 365 * 86_400), period: .unlimited,
            calendar: calendar)
        #expect(await store.all().count == 1)
    }

    @Test func deletesOneEntryAndAll() async throws {
        let store = HistoryStore(folder: folder)
        let first = try #require(
            try await store.add(
                transcript: "1", cleaned: nil, audio: [0], at: created, period: .oneDay))
        try await store.add(transcript: "2", cleaned: nil, audio: [0], at: created, period: .oneDay)
        try await store.delete(first.id)
        #expect(await store.all().map(\.transcript) == ["2"])
        try await store.deleteAll()
        #expect(await store.all().isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(files == ["index.json"])
    }

    @Test func neverReplacesAnIndexItCouldNotRead() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let index = folder.appending(path: "index.json")
        try Data("not json".utf8).write(to: index)
        let store = HistoryStore(folder: folder)
        await #expect(throws: (any Error).self) {
            try await store.add(
                transcript: "t", cleaned: nil, audio: nil, at: created, period: .oneDay)
        }
        #expect(try Data(contentsOf: index) == Data("not json".utf8))
    }
}
