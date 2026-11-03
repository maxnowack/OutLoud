import Foundation
import OutloudKit

/// Owns the lip reader's files in Application Support — the user's adapters and training
/// samples; no other code reads or writes these paths (`OutloudKit/AGENTS.md` §"Persistence").
/// The model is `ModelCatalog.lipReading`, downloaded into the Hugging Face cache by the
/// `ModelStore`; its snapshot folder is handed in and only read.
public struct LipReadingFiles: Sendable {
    public let root: URL
    public let model: URL

    public init(root: URL, model: URL) {
        self.root = root
        self.model = model
    }

    public var samples: URL { root.appending(path: "Samples") }
    public var adapters: URL { root.appending(path: "Adapters") }

    /// Whether the model is installed for `language`.
    public func hasModel(language: String) -> Bool {
        ["encoder.safetensors", "decoder-\(language).safetensors", "vocabulary-\(language).json"]
            .allSatisfy {
                FileManager.default.fileExists(
                    atPath: model.appending(path: $0).path(percentEncoded: false))
            }
    }

    /// The licences and attributions of the lip-reading model, its runtime and its data, for the
    /// app's acknowledgements.
    public static let acknowledgements: [(name: String, notice: String)] = [
        (
            "Auto-AVSR",
            "The lip-reading model, by Pingchuan Ma et al.: code under the Apache License 2.0; weights for non-commercial use, under the terms of their training data LRS2, LRS3, VoxCeleb2 and AVSpeech (github.com/mpc001/auto_avsr)"
        ),
        ("MLX Swift", "Apple, MIT License (github.com/ml-explore/mlx-swift)"),
        (
            "German lip reading",
            "Trained on videos from Wikimedia Commons under CC BY and CC BY-SA licences; their titles, authors and licences are listed in SOURCES.md beside the model"
        ),
    ]

}

/// A recording's mouth frames with the text they say: a voiced dictation's transcript, or the
/// sentence of a silent practice (`plans/LIP_READING.md` §"Phase 5").
public struct TrainingSample: Codable, Sendable, Equatable {
    public let id: UUID
    public let text: String
    public let language: String
    public let frames: Int
    public let silent: Bool
    public let date: Date
}

extension LipReadingFiles {
    /// Keeps a sample: the crops compressed with LZFSE, the text beside them.
    @discardableResult
    public func keep(
        _ frames: MouthFrames, text: String, language: String, silent: Bool, date: Date
    ) throws -> TrainingSample {
        try FileManager.default.createDirectory(at: samples, withIntermediateDirectories: true)
        let sample = TrainingSample(
            id: UUID(), text: text, language: language, frames: frames.frames, silent: silent,
            date: date)
        let pixels = try (Data(frames.pixels) as NSData).compressed(using: .lzfse) as Data
        try pixels.write(to: samples.appending(path: "\(sample.id).lips"), options: .atomic)
        try JSONEncoder().encode(sample).write(
            to: samples.appending(path: "\(sample.id).json"), options: .atomic)
        return sample
    }

    /// Every sample kept, oldest first.
    public func trainingSamples() -> [TrainingSample] {
        let names =
            (try? FileManager.default.contentsOfDirectory(
                atPath: samples.path(percentEncoded: false)))
            ?? []
        return names.filter { $0.hasSuffix(".json") }
            .compactMap { try? Data(contentsOf: samples.appending(path: $0)) }
            .compactMap { try? JSONDecoder().decode(TrainingSample.self, from: $0) }
            .sorted { $0.date < $1.date }
    }

    public func frames(of sample: TrainingSample) throws -> MouthFrames {
        let data = try Data(contentsOf: samples.appending(path: "\(sample.id).lips"))
        let pixels = try (data as NSData).decompressed(using: .lzfse) as Data
        return MouthFrames(pixels: [UInt8](pixels), frames: sample.frames)
    }

    /// The bytes the samples take on disk.
    public func samplesSize() -> Int64 {
        let names =
            (try? FileManager.default.contentsOfDirectory(
                atPath: samples.path(percentEncoded: false)))
            ?? []
        return names.reduce(0) { total, name in
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: samples.appending(path: name).path(percentEncoded: false))
            return total + ((attributes?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }

    /// Deletes every sample and the adapters learned from them.
    public func deleteSamples() throws {
        for folder in [samples, adapters]
        where FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: folder)
        }
    }
}
