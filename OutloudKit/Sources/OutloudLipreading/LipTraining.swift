import Foundation
import MLX
import MLXNN
import MLXOptimizers
import OutloudKit

/// A linear layer with a low-rank adapter beside its frozen weight (LoRA, arXiv 2106.09685):
/// the user's fine-tuning learns only `loraA` and `loraB`, a few megabytes, and leaves the
/// shared model unchanged.
final class LoRALinear: Linear {
    @ParameterInfo(key: "lora_a") var loraA: MLXArray
    @ParameterInfo(key: "lora_b") var loraB: MLXArray
    static let rank = 8
    static let scale: Float = 2

    init(_ base: Linear) {
        let (output, input) = base.shape
        let bound = 1 / Float(input).squareRoot()
        _loraA.wrappedValue = MLXRandom.uniform(low: -bound, high: bound, [Self.rank, input])
        _loraB.wrappedValue = MLXArray.zeros([output, Self.rank])
        super.init(weight: base.weight, bias: base.bias)
    }

    override func callAsFunction(_ x: MLXArray) -> MLXArray {
        super.callAsFunction(x) + Self.scale * matmul(matmul(x, loraA.T), loraB.T)
    }
}

extension LipReadingNetwork {
    /// Puts adapters on the attention's query and value projections, in the encoder and the
    /// decoder.
    func addAdapters() {
        let updates = leafModules().flattened().compactMap { path, module -> (String, Module)? in
            guard let linear = module as? Linear, !(module is LoRALinear),
                path.hasSuffix(".linear_q") || path.hasSuffix(".linear_v")
            else { return nil }
            return (path, LoRALinear(linear))
        }
        update(modules: ModuleChildren.unflattened(updates))
    }

    /// The adapters' weights, by their paths.
    func adapterWeights() -> [String: MLXArray] {
        Dictionary(
            uniqueKeysWithValues: parameters().flattened().filter {
                $0.0.hasSuffix(".lora_a") || $0.0.hasSuffix(".lora_b")
            })
    }
}

extension LipReadingFiles {
    public func adapter(language: String) -> URL? {
        let url = adapters.appending(path: "adapter-\(language).safetensors")
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }
}

extension LipReader {
    /// The reader the app reads with: 16-bit weights, half the memory of training's 32 bits,
    /// with the user's adapter of `language` when `adapted` and one was learned.
    public static func forReading(files: LipReadingFiles, language: String, adapted: Bool = true)
        throws -> LipReader
    {
        try load(
            from: files.model, language: language,
            adapter: adapted ? files.adapter(language: language) : nil, precision: .float16)
    }

    /// Loads the model with the user's adapter, when one is given.
    public static func load(
        from folder: URL, language: String, adapter: URL?, precision: DType = .float32
    ) throws -> LipReader {
        let reader = try load(from: folder, language: language, precision: precision)
        if let adapter {
            reader.network.addAdapters()
            try reader.network.update(
                parameters: ModuleParameters.unflattened(
                    loadArrays(url: adapter).mapValues { $0.asType(precision) }),
                verify: [])
            eval(reader.network)
        }
        return reader
    }
}

/// One training example: the front end's features of a sample and its tokens.
struct TrainingExample {
    let features: MLXArray  // [frames, 512]
    let tokens: [Int]
    let text: String
}

/// Fine-tunes the lip reader on the user's samples (`plans/LIP_READING.md` §"Phase 4"), or
/// trains a language's decoder (§"Phase 3"). The front end is frozen, so that its features are
/// computed once per sample.
public enum LipTraining {
    public struct Report: Sendable {
        public let samples: Int
        public let heldOut: Int
        public let errorBefore: Double
        public let errorAfter: Double
        public let adopted: Bool
        public let seconds: Double
    }

    /// How far a training is: its samples' features first, then the rounds over them.
    public enum Progress: Equatable, Sendable {
        case preparing(done: Int, of: Int)
        case learning(round: Int, of: Int, batch: Int, batches: Int)

        /// The share done of the step it is in, 0 to 1.
        public var fraction: Double {
            switch self {
            case .preparing(let done, let of): of == 0 ? 0 : Double(done) / Double(of)
            case .learning(let round, let of, let batch, let batches):
                of == 0 || batches == 0
                    ? 0 : (Double(round - 1) + Double(batch) / Double(batches)) / Double(of)
            }
        }
    }

    /// The most frames a batch holds. A longer sample makes a batch of its own above it, and
    /// the largest batch sets a training's peak memory: an 81-second sample took 6.25 GB of
    /// the 6 GB `LipReader.memoryBudget` counts MLX's share of (`plans/LIP_READING.md`).
    static let maximumFrames = 1600

    /// The samples a training learns from: those of `language` that fit in a batch.
    static func usable(_ samples: [TrainingSample], language: String) -> [TrainingSample] {
        samples.filter { $0.language == language && $0.frames <= maximumFrames }
    }

    public enum Mode: Sendable {
        /// Adapters on the attention; the user's fine-tuning.
        case adapters
        /// The whole decoder; a new language's decoder from the samples of that language.
        case decoder
    }

    public enum TrainingError: Error {
        case tooFewSamples(Int)
        /// `stops` asked for it; nothing of the run was written.
        case stopped
    }

    /// Every tenth sample (by its id) is held back to judge the result.
    public static func isHeldOut(_ sample: TrainingSample) -> Bool {
        sample.id.uuid.0 % 10 == 0
    }

    /// Trains on the samples of `language` and writes the result only when it reads the held-back
    /// samples better than what is installed: the adapter for `.adapters`, the decoder for
    /// `.decoder` (into `output`). The learning rate is measured: on 15 minutes of one speaker,
    /// 5e-4 doubled the word error and 1e-4 lowered it by a fifth (`plans/LIP_READING.md`
    /// §"Phase 4"). `stops` is asked before each sample's features and each step; when it says
    /// so, the run ends with `TrainingError.stopped`. `progress` is told before each sample's
    /// features and each batch.
    public static func train(
        files: LipReadingFiles, language: String, mode: Mode = .adapters, epochs: Int = 6,
        learningRate: Float = 1e-4, output: URL? = nil,
        log: (String) -> Void = { _ in }, progress: (Progress) -> Void = { _ in },
        stops: () -> Bool = { false }
    ) throws -> Report {
        let start = ContinuousClock.now
        let samples = usable(files.trainingSamples(), language: language)
        let held = samples.filter(isHeldOut)
        let training = samples.filter { !isHeldOut($0) }
        guard training.count >= 8, !held.isEmpty else {
            throw TrainingError.tooFewSamples(samples.count)
        }
        let reader = try LipReader.load(
            from: files.model, language: language,
            adapter: mode == .adapters ? files.adapter(language: language) : nil)
        let network = reader.network
        var prepared = 0
        func examples(_ some: [TrainingSample]) throws -> [TrainingExample] {
            try some.map { sample in
                if stops() { throw TrainingError.stopped }
                progress(.preparing(done: prepared, of: samples.count))
                prepared += 1
                let frames = try files.frames(of: sample)
                let features = LipReader.lane.withLock {
                    let features = reader.features(frames).squeezed(axis: 0)
                    eval(features)
                    return features
                }
                return TrainingExample(
                    features: features, tokens: reader.vocabulary.encode(sample.text),
                    text: sample.text)
            }
        }
        log("computing features of \(samples.count) samples")
        let train = try examples(training)
        let test = try examples(held)
        let before = try errorRate(reader, test)
        log("word error before: \(String(format: "%.1f", before * 100)) %")

        network.freeze()
        switch mode {
        case .adapters:
            if files.adapter(language: language) == nil { network.addAdapters() }
            network.unfreeze(keys: ["lora_a", "lora_b"])
        case .decoder:
            network.decoder.unfreeze()
        }
        let optimizer = AdamW(learningRate: learningRate, weightDecay: 0.01)
        let step = valueAndGrad(model: network) { network, arrays in
            [
                loss(
                    network, features: arrays[0], mask: arrays[1], input: arrays[2],
                    target: arrays[3])
            ]
        }
        var judgement = Judgement(before: before)
        var best = network.trainableParameters()
        for epoch in 1...epochs {
            var total: Float = 0
            let batches = batches(
                of: train.shuffled(), endOfSentence: reader.vocabulary.endOfSentence)
            for (index, batch) in batches.enumerated() {
                if stops() { throw TrainingError.stopped }
                progress(.learning(round: epoch, of: epochs, batch: index, batches: batches.count))
                try LipReader.checkMemory()
                total += LipReader.lane.withLock {
                    let (losses, gradients) = step(network, batch)
                    optimizer.update(model: network, gradients: gradients)
                    eval(network, optimizer)
                    return losses[0].item(Float.self)
                }
            }
            let error = try errorRate(reader, test)
            log(
                "epoch \(epoch): loss \(String(format: "%.3f", total / Float(batches.count))), "
                    + "word error \(String(format: "%.1f", error * 100)) %")
            if judgement.record(error) { best = network.trainableParameters() }
        }
        LipReader.lane.withLock {
            network.update(parameters: best)
            eval(network)
        }
        let (after, adopted) = (judgement.lowest, judgement.adopted)
        if adopted {
            switch mode {
            case .adapters:
                try FileManager.default.createDirectory(
                    at: files.adapters, withIntermediateDirectories: true)
                try save(
                    arrays: network.adapterWeights().mapValues { $0.asType(.float16) },
                    url: files.adapters.appending(path: "adapter-\(language).safetensors"))
            case .decoder:
                let weights = network.parameters().flattened().filter {
                    $0.0.hasPrefix("decoder.")
                }
                try save(
                    arrays: Dictionary(uniqueKeysWithValues: weights).mapValues {
                        $0.asType(.float16)
                    },
                    // Beside the samples, not into the model's cache: a new decoder is published
                    // as the model's next revision (`plans/LIP_READING.md` §"Phase 7").
                    url: output ?? files.root.appending(path: "decoder-\(language).safetensors"))
            }
        }
        let elapsed = ContinuousClock.now - start
        return Report(
            samples: training.count, heldOut: held.count, errorBefore: before, errorAfter: after,
            adopted: adopted,
            seconds: Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) / 1e18)
    }

    /// Which epoch is kept: the one that reads the held-back samples best — not the last —, and
    /// only one that reads them better than what was installed before.
    struct Judgement {
        private(set) var best: Double
        private(set) var adopted = false
        /// The lowest word error of any epoch, for the report, adopted or not.
        private(set) var lowest = Double.infinity

        init(before: Double) { best = before }

        /// Records an epoch's word error; `true` when it is the best so far.
        mutating func record(_ error: Double) -> Bool {
            lowest = min(lowest, error)
            guard error < best else { return false }
            (best, adopted) = (error, true)
            return true
        }
    }

    /// Batches of similar length, padded: features, frame mask, decoder input and target
    /// (−1 where padded).
    static func batches(of examples: [TrainingExample], endOfSentence: Int) -> [[MLXArray]] {
        var result: [[MLXArray]] = []
        var current: [TrainingExample] = []
        func flush() {
            guard !current.isEmpty else { return }
            let frames = current.map { $0.features.dim(0) }.max()!
            let length = current.map(\.tokens.count).max()! + 1
            let features = stacked(
                current.map {
                    padded($0.features, widths: [.init((0, frames - $0.features.dim(0))), 0])
                })
            let mask = MLXArray(
                current.flatMap { e in (0..<frames).map { $0 < e.features.dim(0) } },
                [
                    current.count, 1, 1, frames,
                ])
            let input = current.flatMap { e in
                ([endOfSentence] + e.tokens + Array(repeating: endOfSentence, count: length))
                    .prefix(length).map(Int32.init)
            }
            let target = current.flatMap { e in
                (e.tokens + [endOfSentence] + Array(repeating: -1, count: length)).prefix(length)
                    .map(Int32.init)
            }
            result.append([
                features, mask, MLXArray(input, [current.count, length]),
                MLXArray(target, [current.count, length]),
            ])
            current = []
        }
        for example in examples.sorted(by: { $0.features.dim(0) < $1.features.dim(0) }) {
            let frames = max(current.map { $0.features.dim(0) }.max() ?? 0, example.features.dim(0))
            if (current.count + 1) * frames > maximumFrames { flush() }
            current.append(example)
        }
        flush()
        return result.shuffled()
    }

    /// The attention loss with label smoothing 0.1, as Auto-AVSR's, over the tokens that are not
    /// padding.
    static func loss(
        _ network: LipReadingNetwork, features: MLXArray, mask: MLXArray, input: MLXArray,
        target: MLXArray
    ) -> MLXArray {
        let memory = network.encode(features: features, mask: mask)
        let logits = network.decoder(input, memory: memory, memoryMask: mask)
        let valid = target .>= 0
        let losses = crossEntropy(
            logits: logits, targets: MLX.maximum(target, 0), labelSmoothing: 0.1)
        return (losses * valid).sum() / valid.sum()
    }

    /// The word error rate of the reader on `examples`.
    static func errorRate(_ reader: LipReader, _ examples: [TrainingExample]) throws -> Double {
        var errors = 0
        var words = 0
        for example in examples {
            let text = try LipReader.lane.withLock {
                let memory = reader.network.encode(
                    features: example.features.expandedDimensions(axis: 0))
                return try reader.decode(
                    memory: memory, frames: example.features.dim(0), beamSize: 4)
            }
            let reference = Vocabulary.normalise(example.text).split(separator: " ").map(
                String.init)
            errors += WordErrors.count(reference, text.split(separator: " ").map(String.init))
            words += reference.count
        }
        return words == 0 ? 0 : Double(errors) / Double(words)
    }
}

/// Word-level edit distance: substitutions, insertions and deletions.
public enum WordErrors {
    public static func count(_ reference: [String], _ hypothesis: [String]) -> Int {
        var previous = Array(0...hypothesis.count)
        for (i, word) in reference.enumerated() {
            var current = [i + 1]
            for (j, other) in hypothesis.enumerated() {
                current.append(
                    min(previous[j + 1] + 1, current[j] + 1, previous[j] + (word == other ? 0 : 1)))
            }
            previous = current
        }
        return previous[hypothesis.count]
    }
}
