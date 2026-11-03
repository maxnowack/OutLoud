import Foundation
import MLX
import MLXNN

// Auto-AVSR's visual speech recogniser (arXiv 2303.14307), ported from its PyTorch code
// (github.com/mpc001/auto_avsr, Apache 2.0) layer by layer, so that its weights load unchanged
// apart from the channels-last layout of the convolutions (`plans/LIP_READING.md`).
// Shapes: video [batch, frames, 88, 88, 1]; features [batch, frames, 768].

let modelDimension = 768
let headCount = 12

/// A block of ResNet-18: two 3 × 3 convolutions with a shortcut.
final class BasicBlock: Module, UnaryLayer {
    final class Downsample: Module, UnaryLayer {
        let conv: Conv2d
        let bn: BatchNorm

        init(_ input: Int, _ output: Int, stride: Int) {
            conv = Conv2d(
                inputChannels: input, outputChannels: output, kernelSize: 1, stride: .init(stride),
                bias: false)
            bn = BatchNorm(featureCount: output)
        }

        func callAsFunction(_ x: MLXArray) -> MLXArray { bn(conv(x)) }
    }

    let conv1: Conv2d
    let bn1: BatchNorm
    let conv2: Conv2d
    let bn2: BatchNorm
    let downsample: Downsample?

    init(_ input: Int, _ output: Int, stride: Int) {
        conv1 = Conv2d(
            inputChannels: input, outputChannels: output, kernelSize: 3, stride: .init(stride),
            padding: 1, bias: false)
        bn1 = BatchNorm(featureCount: output)
        conv2 = Conv2d(
            inputChannels: output, outputChannels: output, kernelSize: 3, padding: 1, bias: false)
        bn2 = BatchNorm(featureCount: output)
        downsample =
            stride != 1 || input != output ? Downsample(input, output, stride: stride) : nil
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let out = bn2(conv2(silu(bn1(conv1(x)))))
        return silu(out + (downsample?(x) ?? x))
    }
}

final class ResNetTrunk: Module, UnaryLayer {
    let layer1: [BasicBlock]
    let layer2: [BasicBlock]
    let layer3: [BasicBlock]
    let layer4: [BasicBlock]

    override init() {
        layer1 = [BasicBlock(64, 64, stride: 1), BasicBlock(64, 64, stride: 1)]
        layer2 = [BasicBlock(64, 128, stride: 2), BasicBlock(128, 128, stride: 1)]
        layer3 = [BasicBlock(128, 256, stride: 2), BasicBlock(256, 256, stride: 1)]
        layer4 = [BasicBlock(256, 512, stride: 2), BasicBlock(512, 512, stride: 1)]
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        var x = x
        for block in layer1 + layer2 + layer3 + layer4 { x = block(x) }
        return x.mean(axes: [1, 2])
    }
}

/// The visual front end: a 3D convolution over five frames, then ResNet-18 per frame.
final class VisualFrontend: Module, UnaryLayer {
    let conv3d: Conv3d
    @ModuleInfo(key: "bn3d") var bn3d: BatchNorm
    let pool = MaxPool2d(kernelSize: 3, stride: 2, padding: 1)
    let trunk = ResNetTrunk()

    override init() {
        conv3d = Conv3d(
            inputChannels: 1, outputChannels: 64, kernelSize: .init((5, 7, 7)),
            stride: .init((1, 2, 2)), padding: .init((2, 3, 3)), bias: false)
        _bn3d.wrappedValue = BatchNorm(featureCount: 64)
    }

    func callAsFunction(_ video: MLXArray) -> MLXArray {
        let (batch, frames) = (video.dim(0), video.dim(1))
        // MLX's BatchNorm takes at most four dimensions; per channel, frames are as batches.
        var x = conv3d(video)
        x = silu(bn3d(x.reshaped(batch * frames, x.dim(2), x.dim(3), x.dim(4))))
        return trunk(pool(x)).reshaped(batch, frames, 512)
    }
}

final class FeedForward: Module, UnaryLayer {
    @ModuleInfo(key: "w_1") var w1: Linear
    @ModuleInfo(key: "w_2") var w2: Linear

    init(_ dimension: Int, _ hidden: Int) {
        _w1.wrappedValue = Linear(dimension, hidden)
        _w2.wrappedValue = Linear(hidden, dimension)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray { w2(relu(w1(x))) }
}

/// Multi-headed attention; `mask` is true where a key may be attended to.
class Attention: Module {
    @ModuleInfo(key: "linear_q") var linearQ: Linear
    @ModuleInfo(key: "linear_k") var linearK: Linear
    @ModuleInfo(key: "linear_v") var linearV: Linear
    @ModuleInfo(key: "linear_out") var linearOut: Linear

    override init() {
        _linearQ.wrappedValue = Linear(modelDimension, modelDimension)
        _linearK.wrappedValue = Linear(modelDimension, modelDimension)
        _linearV.wrappedValue = Linear(modelDimension, modelDimension)
        _linearOut.wrappedValue = Linear(modelDimension, modelDimension)
    }

    /// [batch, time, dimension] → [batch, heads, time, headDimension]
    func heads(_ x: MLXArray) -> MLXArray {
        x.reshaped(x.dim(0), x.dim(1), headCount, -1).transposed(0, 2, 1, 3)
    }

    func attend(_ scores: MLXArray, _ value: MLXArray, mask: MLXArray?) -> MLXArray {
        var scores = scores
        if let mask {
            scores = MLX.where(mask, scores, MLXArray(-Float.greatestFiniteMagnitude))
        }
        let out = matmul(softmax(scores, axis: -1, precise: true), value)
        return linearOut(out.transposed(0, 2, 1, 3).reshaped(value.dim(0), -1, modelDimension))
    }

    func callAsFunction(_ query: MLXArray, _ memory: MLXArray, mask: MLXArray?) -> MLXArray {
        let q = heads(linearQ(query))
        let k = heads(linearK(memory))
        let v = heads(linearV(memory))
        let scale = 1 / Float(modelDimension / headCount).squareRoot()
        return attend(matmul(q, k.transposed(0, 1, 3, 2)) * scale, v, mask: mask)
    }
}

/// Self-attention with relative positions (Transformer-XL style, as in ESPnet's conformer).
final class RelativeAttention: Attention {
    @ModuleInfo(key: "linear_pos") var linearPos: Linear
    @ParameterInfo(key: "pos_bias_u") var biasU: MLXArray
    @ParameterInfo(key: "pos_bias_v") var biasV: MLXArray

    override init() {
        _linearPos.wrappedValue = Linear(modelDimension, modelDimension, bias: false)
        _biasU.wrappedValue = MLXArray.zeros([headCount, modelDimension / headCount])
        _biasV.wrappedValue = MLXArray.zeros([headCount, modelDimension / headCount])
        super.init()
    }

    func callAsFunction(_ x: MLXArray, positions: MLXArray, mask: MLXArray?) -> MLXArray {
        let time = x.dim(1)
        let q = linearQ(x).reshaped(x.dim(0), time, headCount, -1)
        let k = heads(linearK(x))
        let v = heads(linearV(x))
        let p = heads(linearPos(positions))
        let ac = matmul((q + biasU).transposed(0, 2, 1, 3), k.transposed(0, 1, 3, 2))
        var bd = matmul((q + biasV).transposed(0, 2, 1, 3), p.transposed(0, 1, 3, 2))
        // Relative shift: score (i, j) is the one for distance j − i, at column T − 1 − i + j.
        let rows = MLXArray(0..<Int32(time)).reshaped(time, 1)
        let columns = MLXArray(0..<Int32(time)).reshaped(1, time)
        let index = broadcast(Int32(time - 1) - rows + columns, to: [1, 1, time, time])
        bd = takeAlong(bd, broadcast(index, to: [bd.dim(0), bd.dim(1), time, time]), axis: -1)
        let scale = 1 / Float(modelDimension / headCount).squareRoot()
        return attend((ac + bd) * scale, v, mask: mask)
    }
}

final class ConvolutionModule: Module, UnaryLayer {
    @ModuleInfo(key: "pointwise_cov1") var pointwise1: Conv1d
    @ModuleInfo(key: "depthwise_conv") var depthwise: Conv1d
    let norm: BatchNorm
    @ModuleInfo(key: "pointwise_cov2") var pointwise2: Conv1d

    override init() {
        _pointwise1.wrappedValue = Conv1d(
            inputChannels: modelDimension, outputChannels: 2 * modelDimension, kernelSize: 1)
        _depthwise.wrappedValue = Conv1d(
            inputChannels: modelDimension, outputChannels: modelDimension, kernelSize: 31,
            padding: 15, groups: modelDimension)
        norm = BatchNorm(featureCount: modelDimension)
        _pointwise2.wrappedValue = Conv1d(
            inputChannels: modelDimension, outputChannels: modelDimension, kernelSize: 1)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let gated = glu(pointwise1(x), axis: -1)
        return pointwise2(silu(norm(depthwise(gated))))
    }
}

/// ESPnet's LayerNorm: epsilon 1e-12.
func layerNorm() -> LayerNorm { LayerNorm(dimensions: modelDimension, eps: 1e-12) }

final class ConformerLayer: Module {
    @ModuleInfo(key: "self_attn") var selfAttention: RelativeAttention
    @ModuleInfo(key: "feed_forward") var feedForward: FeedForward
    @ModuleInfo(key: "feed_forward_macaron") var feedForwardMacaron: FeedForward
    @ModuleInfo(key: "conv_module") var convolution: ConvolutionModule
    @ModuleInfo(key: "norm_ff") var normFF: LayerNorm
    @ModuleInfo(key: "norm_mha") var normMHA: LayerNorm
    @ModuleInfo(key: "norm_ff_macaron") var normFFMacaron: LayerNorm
    @ModuleInfo(key: "norm_conv") var normConv: LayerNorm
    @ModuleInfo(key: "norm_final") var normFinal: LayerNorm

    override init() {
        _selfAttention.wrappedValue = RelativeAttention()
        _feedForward.wrappedValue = FeedForward(modelDimension, 3072)
        _feedForwardMacaron.wrappedValue = FeedForward(modelDimension, 3072)
        _convolution.wrappedValue = ConvolutionModule()
        _normFF.wrappedValue = layerNorm()
        _normMHA.wrappedValue = layerNorm()
        _normFFMacaron.wrappedValue = layerNorm()
        _normConv.wrappedValue = layerNorm()
        _normFinal.wrappedValue = layerNorm()
    }

    func callAsFunction(_ x: MLXArray, positions: MLXArray, mask: MLXArray?) -> MLXArray {
        var x = x + 0.5 * feedForwardMacaron(normFFMacaron(x))
        x = x + selfAttention(normMHA(x), positions: positions, mask: mask)
        x = x + convolution(normConv(x))
        x = x + 0.5 * feedForward(normFF(x))
        return normFinal(x)
    }
}

/// Sinusoidal encodings for the given positions: [positions, dimension], sin and cos interleaved.
func sinusoids(_ positions: MLXArray) -> MLXArray {
    let frequencies = exp(
        MLXArray(stride(from: 0, to: modelDimension, by: 2).map { Float($0) })
            * -(log(10000) / Float(modelDimension)))
    let angles = positions.asType(.float32).reshaped(-1, 1) * frequencies.reshaped(1, -1)
    return stacked([sin(angles), cos(angles)], axis: -1).reshaped(-1, modelDimension)
}

final class ConformerEncoder: Module {
    let encoders: [ConformerLayer]
    @ModuleInfo(key: "after_norm") var afterNorm: LayerNorm

    override init() {
        encoders = (0..<12).map { _ in ConformerLayer() }
        _afterNorm.wrappedValue = layerNorm()
    }

    /// `mask`: [batch, 1, 1, time], true for frames that are not padding.
    func callAsFunction(_ x: MLXArray, mask: MLXArray?) -> MLXArray {
        let time = x.dim(1)
        // Relative positions T − 1 down to −(T − 1).
        let positions = sinusoids(
            MLXArray(stride(from: Int32(time - 1), through: Int32(1 - time), by: -1))
        )
        .asType(x.dtype).expandedDimensions(axis: 0)
        var x = x * Float(modelDimension).squareRoot()
        for layer in encoders { x = layer(x, positions: positions, mask: mask) }
        return afterNorm(x)
    }
}

final class DecoderLayer: Module {
    @ModuleInfo(key: "self_attn") var selfAttention: Attention
    @ModuleInfo(key: "src_attn") var sourceAttention: Attention
    @ModuleInfo(key: "feed_forward") var feedForward: FeedForward
    let norm1: LayerNorm
    let norm2: LayerNorm
    let norm3: LayerNorm

    override init() {
        _selfAttention.wrappedValue = Attention()
        _sourceAttention.wrappedValue = Attention()
        _feedForward.wrappedValue = FeedForward(modelDimension, 3072)
        norm1 = layerNorm()
        norm2 = layerNorm()
        norm3 = layerNorm()
    }

    func callAsFunction(
        _ x: MLXArray, causal: MLXArray, memory: MLXArray, memoryMask: MLXArray?
    ) -> MLXArray {
        let n1 = norm1(x)
        var x = x + selfAttention(n1, n1, mask: causal)
        x = x + sourceAttention(norm2(x), memory, mask: memoryMask)
        return x + feedForward(norm3(x))
    }
}

final class TransformerDecoder: Module {
    let embed: Embedding
    let decoders: [DecoderLayer]
    @ModuleInfo(key: "after_norm") var afterNorm: LayerNorm
    @ModuleInfo(key: "output_layer") var outputLayer: Linear

    init(vocabularySize: Int) {
        embed = Embedding(embeddingCount: vocabularySize, dimensions: modelDimension)
        decoders = (0..<6).map { _ in DecoderLayer() }
        _afterNorm.wrappedValue = layerNorm()
        _outputLayer.wrappedValue = Linear(modelDimension, vocabularySize)
    }

    /// Logits for every position of `tokens` [batch, length] given `memory`.
    func callAsFunction(_ tokens: MLXArray, memory: MLXArray, memoryMask: MLXArray?) -> MLXArray {
        let length = tokens.dim(1)
        let positions = sinusoids(MLXArray(0..<Int32(length))).asType(memory.dtype)
        var x = embed(tokens) * Float(modelDimension).squareRoot() + positions
        let causal = tril(MLXArray.ones([length, length], type: Bool.self))
        for layer in decoders {
            x = layer(x, causal: causal, memory: memory, memoryMask: memoryMask)
        }
        return outputLayer(afterNorm(x))
    }
}

/// The whole network. The encoder (front end and conformer) reads the lips; the decoder writes
/// the tokens of one language. Auto-AVSR's CTC head is left out: decoding is attention-only.
final class LipReadingNetwork: Module {
    let frontend = VisualFrontend()
    @ModuleInfo(key: "proj_encoder") var projection: Linear
    let encoder = ConformerEncoder()
    let decoder: TransformerDecoder

    init(vocabularySize: Int) {
        _projection.wrappedValue = Linear(512, modelDimension)
        decoder = TransformerDecoder(vocabularySize: vocabularySize)
    }

    /// Encoder features from the front end's output.
    func encode(features: MLXArray, mask: MLXArray? = nil) -> MLXArray {
        encoder(projection(features), mask: mask)
    }
}
