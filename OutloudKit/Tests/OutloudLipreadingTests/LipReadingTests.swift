import Foundation
import OutloudKit
import Testing

@testable import OutloudLipreading

struct VocabularyTests {
    // A toy vocabulary: blank, unknown, pieces, end of sentence.
    let vocabulary = Vocabulary(
        pieces: ["<blank>", "<unk>", "▁HELLO", "▁HE", "LLO", "▁W", "OR", "LD", "▁WORLD", "<eos>"],
        scores: [0, 0, -3, -2, -2, -2, -2, -2, -7, 0])

    @Test func normalisesAsTheTrainingLabels() {
        #expect(
            Vocabulary.normalise("Hello, world! It's 3 o'clock.") == "HELLO WORLD IT'S 3 O'CLOCK")
        #expect(Vocabulary.normalise("Grüße  aus Köln") == "GRÜSSE AUS KÖLN")
    }

    @Test func encodesTheMostProbableSegmentation() {
        // ▁HELLO (−3) beats ▁HE + LLO (−4); ▁W OR LD (−6) beats ▁WORLD (−7).
        #expect(vocabulary.encode("hello world") == [2, 5, 6, 7])
    }

    @Test func marksCharactersNoPieceCovers() {
        #expect(vocabulary.encode("hello x") == [2, 1, 1])
    }

    @Test func decodesWithoutBlankAndEnd() {
        #expect(vocabulary.decode([0, 2, 5, 6, 7, 9]) == "HELLO WORLD")
    }
}

struct BeamSearchTests {
    @Test func findsTheBestSequenceAGreedySearchMisses() {
        // Tokens: 0 = end. Greedy takes 1 (−0.4) and then can only end badly; 2 then 3 wins.
        let table: [[Int]: [Float]] = [
            [0]: [-9, -0.4, -1.1, -9],
            [0, 1]: [-3, -9, -9, -9],
            [0, 2]: [-9, -9, -9, -0.1],
            [0, 2, 3]: [-0.1, -9, -9, -9],
        ]
        let search = BeamSearch(beamSize: 2, endOfSentence: 0, maximumLength: 5)
        let tokens = search.run { prefixes in prefixes.map { table[$0] ?? [0, -9, -9, -9] } }
        #expect(tokens == [2, 3])
    }

    @Test func stopsAtTheMaximumLength() {
        let search = BeamSearch(beamSize: 1, endOfSentence: 0, maximumLength: 3)
        let tokens = search.run { prefixes in prefixes.map { _ in [-9, -0.1] } }
        #expect(tokens == [1, 1, 1])
    }
}

struct MouthCropTests {
    @Test func similarityMapsPointsItWasFittedOn() {
        let source: [SIMD2<Double>] = [[10, 10], [30, 10], [20, 25], [20, 32]]
        // Rotated by 90°, scaled by 2, shifted.
        let target = source.map { SIMD2(-2 * $0.y + 100, 2 * $0.x + 50) }
        let fit = Similarity.fitting(source, to: target)
        for (s, t) in zip(source, target) {
            #expect(abs(fit.apply(s).x - t.x) < 1e-9 && abs(fit.apply(s).y - t.y) < 1e-9)
            let back = fit.inverse().apply(t)
            #expect(abs(back.x - s.x) < 1e-9 && abs(back.y - s.y) < 1e-9)
        }
    }

    /// An image whose grey level is its x coordinate, a face drawn at the mean face's points.
    func ramp() -> GreyImage {
        let (width, height) = (256, 256)
        let pixels = (0..<height).flatMap { _ in (0..<width).map { UInt8($0) } }
        return GreyImage(width: width, height: height, bytesPerRow: width, pixels: pixels)
    }

    @Test func cropsTheSquareAroundTheMouth() {
        let crop = MouthCrop.crop(ramp(), FacePoints(MouthCrop.reference))
        // The mouth is at x ≈ 129.3, so the crop starts at 129 − 48 = 81.
        #expect(crop.count == MouthCrop.size * MouthCrop.size)
        #expect(crop[0] == 81 && crop[95] == 176)
    }

    @Test func holdsFramesUntilTheirWindowIsKnown() {
        let crop = MouthCrop()
        let face = FacePoints(MouthCrop.reference)
        crop.append(ramp(), points: nil)
        for _ in 0..<10 { crop.append(ramp(), points: face) }
        let frames = crop.finish()
        #expect(frames?.frames == 11)
        // The frame without a face took the nearest face.
        #expect(frames?.pixels[0] == 81)
    }

    @Test func givesNothingWithoutAFace() {
        let crop = MouthCrop()
        crop.append(ramp(), points: nil)
        #expect(crop.finish() == nil)
    }
}

struct JudgementTests {
    @Test func keepsTheBestEpochNotTheLast() {
        var judgement = LipTraining.Judgement(before: 0.4)
        let kept = [0.38, 0.33, 0.36].map { judgement.record($0) }
        #expect(kept == [true, true, false])
        #expect(judgement.adopted)
        #expect(judgement.best == 0.33)
    }

    @Test func adoptsNothingThatReadsWorse() {
        var judgement = LipTraining.Judgement(before: 0.4)
        let kept = [0.8, 0.4].map { judgement.record($0) }
        #expect(kept == [false, false])
        #expect(!judgement.adopted)
        #expect(judgement.best == 0.4)
        #expect(judgement.lowest == 0.4)
    }
}

struct LipReadingModelTests {
    @Test func readsEveryLanguageFromTheDownloadedModel() throws {
        let names = Set(ModelCatalog.lipReading.files.map(\.path))
        for language in LipReadingLanguage.all {
            #expect(names.contains("decoder-\(language).safetensors"))
            #expect(names.contains("vocabulary-\(language).json"))
        }
        #expect(names.contains("encoder.safetensors"))

        let folder = FileManager.default.temporaryDirectory.appending(path: "lips-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = LipReadingFiles(root: folder, model: folder)
        for name in ["encoder.safetensors", "decoder-de.safetensors", "vocabulary-de.json"] {
            try Data().write(to: folder.appending(path: name))
        }
        #expect(files.hasModel(language: "de"))
        #expect(!files.hasModel(language: "en"))
    }
}

@MainActor
struct LipReadingCoachTests {
    @Test func trainsOnItsOwnOnlyWhileNobodyIsAtTheMac() {
        let idle = LipReadingCoach.idleAfter
        #expect(
            LipReadingCoach.trainsNow(
                newSamples: 10, idle: idle, onMains: true, running: false, hasModel: true))
        #expect(
            !LipReadingCoach.trainsNow(
                newSamples: 10, idle: idle - 1, onMains: true, running: false, hasModel: true))
        #expect(
            !LipReadingCoach.trainsNow(
                newSamples: 9, idle: idle, onMains: true, running: false, hasModel: true))
        #expect(
            !LipReadingCoach.trainsNow(
                newSamples: 10, idle: idle, onMains: false, running: false, hasModel: true))
        #expect(
            !LipReadingCoach.trainsNow(
                newSamples: 10, idle: idle, onMains: true, running: true, hasModel: true))
        #expect(
            !LipReadingCoach.trainsNow(
                newSamples: 10, idle: idle, onMains: true, running: false, hasModel: false))
    }

    @Test func trainsEveryLanguageWithEnoughNewSamples() {
        let idle = LipReadingCoach.idleAfter
        #expect(
            LipReadingCoach.languagesToTrain(
                newSamples: ["de": 12, "en": 3], idle: idle, onMains: true, running: false,
                hasModel: { _ in true }) == ["de"])
        #expect(
            LipReadingCoach.languagesToTrain(
                newSamples: ["de": 12, "en": 10], idle: idle, onMains: true, running: false,
                hasModel: { _ in true }) == ["de", "en"])
        #expect(
            LipReadingCoach.languagesToTrain(
                newSamples: ["de": 12, "en": 10], idle: idle, onMains: true, running: false,
                hasModel: { $0 == "en" }) == ["en"])
    }

    @Test func saysOnceThatItIsGoodEnough() {
        #expect(!LipReadingCoach.announces(error: 0.30, announced: false))
        #expect(LipReadingCoach.announces(error: 0.29, announced: false))
        #expect(!LipReadingCoach.announces(error: 0.20, announced: true))
    }
}
