import Foundation
import OutloudKit

// A developer tool for the model pipeline without the apps: lists and downloads the models in
// the shared cache, and runs transcription and cleanup on an audio file
// (`plans/FIRST_VERSION.md` §"1. Model spike").

let usage = """
    usage: outloud models
           outloud download [model-id ...]
           outloud delete <model-id>
           outloud dictate <audio-file> [--no-cleanup] [--cleanup-model <file.gguf>]
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

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "models":
    print("cache: \(store.cache.root.path(percentEncoded: false))")
    for model in ModelCatalog.all {
        let installed = await store.isInstalled(model)
        let missing = await store.missingBytes(of: model)
        print(
            "\(model.id)  \(model.purpose.rawValue)  \(megabytes(model.totalSize))  "
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

    var cleaner: QwenCleaner?
    if cleanup {
        start = ContinuousClock.now
        let file: URL
        if let index = arguments.firstIndex(of: "--cleanup-model"), index + 1 < arguments.count {
            file = URL(filePath: arguments[index + 1])
        } else {
            file = try await store.verifiedFolder(of: ModelCatalog.qwen08B)
                .appending(path: "Qwen3.5-0.8B-Q4_K_M.gguf")
        }
        cleaner = try await QwenCleaner.load(from: file)
        print("cleanup model loaded in \(seconds(since: start))")
    }

    start = ContinuousClock.now
    let transcript = try await transcriber.transcribe(samples)
    print("transcribed in \(seconds(since: start)):\n  \(transcript)")
    if let cleaner {
        start = ContinuousClock.now
        let outcome = try await DictationPipeline(
            transcriber: FixedTranscript(text: transcript), cleaner: cleaner
        ).run(samples: samples)
        print(
            "cleaned up in \(seconds(since: start))\(outcome.cleanupFailed ? " (failed, transcript kept)" : ""):\n  \(outcome.result)"
        )
    }

default:
    print(usage)
    QwenCleaner.shutDownBackend()
    exit(64)
}

QwenCleaner.shutDownBackend()

/// Hands the already measured transcript to the pipeline, so that only cleanup is timed.
struct FixedTranscript: Transcribing {
    let text: String
    func transcribe(_ samples: [Float]) async throws -> String { text }
}
