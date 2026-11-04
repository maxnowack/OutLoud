import Foundation
import MLX
import MLXNN
import OutloudKit

extension MouthFrames {
    /// The model's input [1, frames, 88, 88, 1]: the centre 88 × 88, scaled as in training.
    func input() -> MLXArray {
        let size = Self.size
        let all = MLXArray(pixels, [frames, size, size]).asType(.float32)
        let offset = (size - 88) / 2
        let centre = all[0..., offset..<(offset + 88), offset..<(offset + 88)]
        return ((centre / 255 - 0.421) / 0.165).reshaped(1, frames, 88, 88, 1)
    }
}

/// Reads the lips with Auto-AVSR's visual model (`plans/LIP_READING.md`). One instance holds
/// one language's decoder; the encoder is shared between languages.
public final class LipReader: @unchecked Sendable {
    let network: LipReadingNetwork
    public let vocabulary: Vocabulary
    public let language: String
    let precision: DType
    /// MLX runs one computation at a time here: reading and training take turns on the GPU,
    /// training a step at a time, so that a dictation waits at most one step.
    static let lane = NSLock()
    /// The most MLX may hold for reading and training together. Past it a reading or a
    /// training stops with `TooMuchMemory` instead of taking the Mac's memory: a beam search
    /// without a bound grew to 24 GB on 2026-11-04 and brought a 32 GB Mac down.
    public static let memoryBudget = 6 << 30
    /// The freed buffers MLX keeps for reuse. Its default is the whole memory limit, and a beam
    /// search, a new shape at every token, fills it with buffers nobody asks for again.
    static let cacheLimit = 256 << 20

    /// A reading or a training stopped because it needed more than `memoryBudget`.
    public struct TooMuchMemory: Error {}

    /// Throws `TooMuchMemory` once MLX holds more than `memoryBudget`.
    static func checkMemory() throws {
        if Memory.activeMemory > memoryBudget { throw TooMuchMemory() }
    }

    init(network: LipReadingNetwork, vocabulary: Vocabulary, language: String, precision: DType) {
        self.network = network
        self.vocabulary = vocabulary
        self.language = language
        self.precision = precision
    }

    /// Loads `encoder.safetensors`, `decoder-<language>.safetensors` and
    /// `vocabulary-<language>.json` from `folder`, and an adapter if one is given.
    /// - Parameter precision: The weights' type: 16 bits halve the memory, 1 GB at 32.
    public static func load(
        from folder: URL, language: String, precision: DType = .float32
    ) throws -> LipReader {
        Memory.cacheLimit = cacheLimit
        Memory.memoryLimit = memoryBudget
        let vocabulary = try Vocabulary(
            contentsOf: folder.appending(path: "vocabulary-\(language).json"))
        let network = LipReadingNetwork(vocabularySize: vocabulary.count)
        var weights = try loadArrays(url: folder.appending(path: "encoder.safetensors"))
        try weights.merge(
            loadArrays(url: folder.appending(path: "decoder-\(language).safetensors")),
            uniquingKeysWith: { _, new in new })
        try network.update(
            parameters: ModuleParameters.unflattened(weights.mapValues { $0.asType(precision) }),
            verify: [.all])
        network.train(false)
        lane.withLock { eval(network) }
        return LipReader(
            network: network, vocabulary: vocabulary, language: language, precision: precision)
    }

    /// The front end's features [1, frames, 512]; the part training caches.
    func features(_ frames: MouthFrames) -> MLXArray {
        network.frontend(frames.input().asType(precision))
    }

    /// The text the lips say.
    public func read(_ frames: MouthFrames, beamSize: Int = 10) throws -> String {
        try Self.lane.withLock {
            try decode(
                memory: network.encode(features: features(frames)), frames: frames.frames,
                beamSize: beamSize)
        }
    }

    /// The text of the encoder's output for `frames` frames.
    func decode(memory: MLXArray, frames: Int, beamSize: Int) throws -> String {
        let sources = network.decoder.sources(memory)
        eval(sources.flatMap { [$0.keys, $0.values] })
        let search = BeamSearch(
            beamSize: beamSize, endOfSentence: vocabulary.endOfSentence,
            maximumLength: BeamSearch.maximumLength(frames: frames))
        var caches: [KeysValues]?
        let tokens = try search.run { prefixes, parents in
            try Self.checkMemory()
            // Each hypothesis carries on its parent's cache.
            let rows = MLXArray(parents.map(Int32.init))
            let carried = caches?.map { KeysValues(keys: $0.keys[rows], values: $0.values[rows]) }
            let (logits, grown) = network.decoder.step(
                MLXArray(prefixes.map { Int32($0.last!) }, [prefixes.count, 1]),
                position: prefixes[0].count - 1, caches: carried, sources: sources)
            caches = grown
            let last = logSoftmax(logits.asType(.float32), axis: -1)
            return last.asArray(Float.self).chunked(vocabulary.count)
        }
        return vocabulary.decode(tokens)
    }
}

extension Array {
    func chunked(_ size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

extension LipReader {
    /// The largest difference to the PyTorch model's outputs on the same crops, per stage, from
    /// the reference the conversion writes — the check that the port computes what the original
    /// does (`outloud lips check`).
    public func differences(toReference url: URL) throws -> [(stage: String, difference: Float)] {
        let reference = try loadArrays(url: url)
        let crops = reference["crops"]!.asType(.uint8).asArray(UInt8.self)
        let frames = MouthFrames(pixels: crops, frames: reference["crops"]!.dim(0))
        let features = features(frames)
        let memory = network.encode(features: features)
        let prefix = reference["prefix"]!.asType(.int32)
        let logits = network.decoder(prefix, memory: memory, memoryMask: nil)
        func difference(_ a: MLXArray, _ key: String) -> Float {
            abs(a - reference[key]!).max().item(Float.self)
        }
        return [
            ("input", difference(frames.input().reshaped(reference["input"]!.shape), "input")),
            ("frontend", difference(features, "frontend")),
            ("encoder", difference(memory, "encoder")),
            ("decoder", difference(logits, "decoder")),
        ]
    }
}
