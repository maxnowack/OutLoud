import Foundation
import OutloudKit
import OutloudLipreading

// A developer tool for the model pipeline without the apps: lists and downloads the models in
// the shared cache, and runs transcription and cleanup on an audio file
// (`plans/FIRST_VERSION.md` §"1. Model spike").

let usage = """
    usage: outloud models
           outloud download [model-id ...]
           outloud delete <model-id>
           outloud dictate <audio-file> [--no-cleanup]
           outloud lips read <model-folder> <language> <video-file> [<start> <end> ...]
           outloud lips check <model-folder> <language> <reference.safetensors>
           outloud lips sample <video-file> <language> <text>
           outloud lips harvest <pieces-folder> <language>
           outloud lips samples
           outloud lips train <language> [adapters|decoder] [epochs] [learning-rate]
    """

let store = ModelStore(
    cache: .shared(),
    recordURL: try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    ).appending(path: "Outloud/model-verification.json"))

func megabytes(_ bytes: Int64) -> String {
    String(format: "%.1f MB", Double(bytes) / 1_000_000)
}

func seconds(since start: ContinuousClock.Instant) -> String {
    let elapsed = ContinuousClock.now - start
    return String(
        format: "%.2f s",
        Double(elapsed.components.attoseconds) / 1e18 + Double(elapsed.components.seconds))
}

/// The lip reader's files: the app's with the model downloaded into the cache
/// (`outloud download outloud-lipreading`), or with `OUTLOUD_LIPS` set another folder holding
/// the samples and, in `Model/`, a conversion's output, for trials.
func lipFiles() throws -> LipReadingFiles {
    if let root = ProcessInfo.processInfo.environment["OUTLOUD_LIPS"].map({ URL(filePath: $0) }) {
        return LipReadingFiles(root: root, model: root.appending(path: "Model"))
    }
    let support = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return LipReadingFiles(
        root: support.appending(path: "Outloud/LipReading"),
        model: store.cache.snapshotFolder(of: ModelCatalog.lipReading))
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "models":
    print("cache: \(store.cache.root.path(percentEncoded: false))")
    for model in ModelCatalog.downloadable {
        let installed = await store.isInstalled(model)
        let missing = await store.missingBytes(of: model)
        print(
            "\(model.id)  \(megabytes(model.totalSize))  "
                + (installed ? "installed" : "missing \(megabytes(missing))"))
    }

case "download":
    let ids = arguments.dropFirst()
    let models = ids.isEmpty ? ModelCatalog.all : ids.compactMap(ModelCatalog.model(id:))
    for model in models {
        let start = ContinuousClock.now
        try await store.download(model) { completed, total in
            print("\r\(model.id): \(megabytes(completed)) / \(megabytes(total))", terminator: "")
            fflush(stdout)
        }
        _ = try await store.verifiedFolder(of: model)
        print("\n\(model.id): installed and verified in \(seconds(since: start))")
    }

case "delete" where arguments.count >= 2:
    guard let model = ModelCatalog.model(id: arguments[1]) else {
        print("unknown model \(arguments[1])")
        exit(64)
    }
    try await store.delete(model)
    print("\(model.id): deleted")

case "dictate" where arguments.count >= 2:
    let cleanup = !arguments.contains("--no-cleanup")
    let audio = URL(filePath: arguments[1])
    let samples = try AudioFile.samples(of: audio)
    print("audio: \(String(format: "%.1f", Double(samples.count) / 16_000)) s")

    var start = ContinuousClock.now
    let transcriber = try await ParakeetTranscriber.load(
        from: try await store.verifiedFolder(of: ModelCatalog.parakeetV3))
    print("transcription model loaded in \(seconds(since: start))")

    // Apple's on-device model needs no loading (ADR 0019).
    let availability = CleanupAvailability.current
    let cleaner: AppleCleaner? = cleanup && availability == .available ? AppleCleaner() : nil
    if cleanup, cleaner == nil { print("cleanup unavailable: \(availability)") }

    start = ContinuousClock.now
    let transcript = try await transcriber.transcribe(samples)
    print("transcribed in \(seconds(since: start)):\n  \(transcript)")
    if let cleaner {
        start = ContinuousClock.now
        let outcome = try await DictationPipeline(
            transcriber: FixedTranscript(text: transcript), cleaner: cleaner
        ).run(samples: samples)
        print(
            "cleaned up in \(seconds(since: start))\(outcome.cleanup == .failed ? " (failed, transcript kept)" : ""):\n  \(outcome.result)"
        )
    }

case "lips" where arguments.count >= 5 && arguments[1] == "check":
    let reader = try LipReader.load(from: URL(filePath: arguments[2]), language: arguments[3])
    for (stage, difference) in try reader.differences(toReference: URL(filePath: arguments[4])) {
        print("\(stage): largest difference \(difference)")
    }

case "lips" where arguments.count >= 5 && arguments[1] == "read":
    var start = ContinuousClock.now
    let reader = try LipReader.load(
        from: URL(filePath: arguments[2]), language: arguments[3],
        precision: arguments.contains("--half") ? .float16 : .float32)
    print("lip-reading model loaded in \(seconds(since: start))")
    start = ContinuousClock.now
    guard let frames = try await VideoFile.mouthFrames(of: URL(filePath: arguments[4])) else {
        print("no face in the video")
        exit(65)
    }
    print("mouth cropped in \(seconds(since: start)): \(frames.frames) frames")
    let bounds = arguments.dropFirst(5).filter { $0 != "--half" }.compactMap(Double.init)
    let segments =
        bounds.isEmpty
        ? [(0.0, frames.seconds)]
        : stride(from: 0, to: bounds.count - 1, by: 2).map {
            (bounds[$0], bounds[$0 + 1])
        }
    for (from, to) in segments {
        start = ContinuousClock.now
        let text = reader.read(frames.slice(from: from, to: to))
        print("\(from)–\(to) s, read in \(seconds(since: start)):\n  \(text)")
    }

case "lips" where arguments.count >= 5 && arguments[1] == "sample":
    guard let frames = try await VideoFile.mouthFrames(of: URL(filePath: arguments[2])) else {
        print("no face in the video")
        exit(65)
    }
    let sample = try lipFiles().keep(
        frames, text: arguments[4], language: arguments[3], silent: arguments.contains("--silent"),
        date: Date())
    print("kept \(sample.id): \(frames.frames) frames")

case "lips" where arguments.count >= 4 && arguments[1] == "harvest":
    // Training data from a folder of pieces: <name>.mp4 at 25 frames a second with <name>.wav
    // at 16 kHz beside it, labelled by Parakeet as Auto-AVSR labelled VoxCeleb2.
    let folder = URL(filePath: arguments[2])
    let language = arguments[3]
    let files = try lipFiles()
    let transcriber = try await ParakeetTranscriber.load(
        from: try await store.verifiedFolder(of: ModelCatalog.parakeetV3))
    let videos = try FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "mp4" }.sorted { $0.path < $1.path }
    var (kept, faceless, other) = (0, 0, 0)
    for video in videos {
        guard
            let frames = try await VideoFile.mouthFrames(of: video, faces: 0.9, eyes: 25),
            frames.seconds >= 2
        else {
            faceless += 1
            continue
        }
        let text = try await transcriber.transcribe(
            try AudioFile.samples(of: video.deletingPathExtension().appendingPathExtension("wav")))
        guard Vocabulary.normalise(text).split(separator: " ").count >= 3,
            LipReadingLanguage.of(text) == language
        else {
            other += 1
            continue
        }
        _ = try files.keep(frames, text: text, language: language, silent: false, date: Date())
        kept += 1
    }
    print("kept \(kept), without a face \(faceless), other language or too short \(other)")

case "lips" where arguments.count >= 2 && arguments[1] == "samples":
    let files = try lipFiles()
    let samples = files.trainingSamples()
    for language in Set(samples.map(\.language)).sorted() {
        let of = samples.filter { $0.language == language }
        print(
            "\(language): \(of.count) samples, \(of.filter(\.silent).count) silent, "
                + String(format: "%.1f min", Double(of.map(\.frames).reduce(0, +)) / 25 / 60))
    }
    print("on disk: \(megabytes(files.samplesSize()))")

case "lips" where arguments.count >= 3 && arguments[1] == "train":
    let mode: LipTraining.Mode =
        arguments.count > 3 && arguments[3] == "decoder" ? .decoder : .adapters
    let report = try LipTraining.train(
        files: try lipFiles(), language: arguments[2], mode: mode,
        epochs: arguments.count > 4 ? Int(arguments[4]) ?? 6 : 6,
        learningRate: arguments.count > 5 ? Float(arguments[5]) ?? 1e-4 : 1e-4
    ) { print($0) }
    print(
        "trained on \(report.samples), judged on \(report.heldOut) in \(String(format: "%.0f", report.seconds)) s: "
            + String(
                format: "%.1f %% → %.1f %%", report.errorBefore * 100, report.errorAfter * 100)
            + (report.adopted ? ", adopted" : ", not better, not adopted"))

default:
    print(usage)
    exit(64)
}

/// Hands the already measured transcript to the pipeline, so that only cleanup is timed.
struct FixedTranscript: Transcribing {
    let text: String
    func transcribe(_ samples: [Float]) async throws -> String { text }
}
