import Foundation

/// One file of a model repository on Hugging Face, pinned to its content.
///
/// The hash is the file's etag on the hub and the name of its blob in the hub cache: the
/// SHA-256 of the content for files kept in Git LFS, the Git blob SHA-1 otherwise.
public struct ModelFile: Hashable, Sendable {
    public enum Hash: Hashable, Sendable {
        case sha256(String)
        case gitBlob(String)

        public var etag: String {
            switch self {
            case .sha256(let value), .gitBlob(let value): value
            }
        }
    }

    public let path: String
    public let size: Int64
    public let hash: Hash

    static func lfs(_ path: String, size: Int64, sha256: String) -> ModelFile {
        ModelFile(path: path, size: size, hash: .sha256(sha256))
    }

    static func git(_ path: String, size: Int64, blob: String) -> ModelFile {
        ModelFile(path: path, size: size, hash: .gitBlob(blob))
    }
}

/// A model Outloud offers, pinned to one revision of one Hugging Face repository.
public struct ModelDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    /// The repository on Hugging Face, `organisation/name`.
    public let repository: String
    /// The commit the files are pinned to.
    public let revision: String
    public let files: [ModelFile]
    /// The languages the model handles; Outloud offers only multilingual models.
    public let languages: [String]
    /// The attribution the model's licence requires.
    public let attribution: String

    public var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }
}

/// The models Outloud downloads: the transcription model (ADR 0006); the cleanup runs on Apple's
/// on-device model, which needs no download (ADR 0019).
///
/// File lists, sizes and hashes come from the hub's `paths-info` API at the pinned revision.
/// The Parakeet files are the ones `AsrModels.loadLocal(from:version: .v3)` of FluidAudio 0.17.7
/// reads; the optional `CtcHead.mlmodelc` is left out.
public enum ModelCatalog {
    public static let parakeetV3 = ModelDescriptor(
        id: "parakeet-tdt-0.6b-v3",
        displayName: "Parakeet v3",
        repository: "FluidInference/parakeet-tdt-0.6b-v3-coreml",
        revision: "7dd20fe6b1797d35f5e3307e8b1732d9a178edfe",
        files: [
            .lfs(
                "Decoder.mlmodelc/analytics/coremldata.bin", size: 243,
                sha256: "4238c4e81ecd0dc94bd7dfbb60f7e2cc824107c1ffe0387b8607b72833dba350"),
            .lfs(
                "Decoder.mlmodelc/coremldata.bin", size: 554,
                sha256: "18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99"),
            .git(
                "Decoder.mlmodelc/metadata.json", size: 3427,
                blob: "781350d40ed83511afc3bc31a804e6a543e69d04"),
            .git(
                "Decoder.mlmodelc/model.mil", size: 13110,
                blob: "95328ba81ca8dceb16c039e62f1a7d447ede43c2"),
            .lfs(
                "Decoder.mlmodelc/weights/weight.bin", size: 23_604_992,
                sha256: "48adf0f0d47c406c8253d4f7fef967436a39da14f5a65e66d5a4b407be355d41"),
            .lfs(
                "Encoder.mlmodelc/analytics/coremldata.bin", size: 243,
                sha256: "42e638870d73f26b332918a3496ce36793fbb413a81cbd3d16ba01328637a105"),
            .lfs(
                "Encoder.mlmodelc/coremldata.bin", size: 485,
                sha256: "d48034a167a82e88fc3df64f60af963ab3983538271175b8319e7d5720a0fb86"),
            .git(
                "Encoder.mlmodelc/metadata.json", size: 2921,
                blob: "aecde9a8c4ff70c5b5d227a079650fcf5033caee"),
            .git(
                "Encoder.mlmodelc/model.mil", size: 959_769,
                blob: "93d1301ccde7c2ca447af6c01ab05bfda5a5dd2c"),
            .lfs(
                "Encoder.mlmodelc/weights/weight.bin", size: 445_187_200,
                sha256: "e2020f323703477a5b21d7c2d282c403e371afb5962e79877e3033e73ba6f421"),
            .lfs(
                "JointDecisionv3.mlmodelc/analytics/coremldata.bin", size: 243,
                sha256: "26def4bf73dd56d29dee21c8ef97cb8969e62f6120ed1adc91e46828e2737b6c"),
            .lfs(
                "JointDecisionv3.mlmodelc/coremldata.bin", size: 521,
                sha256: "f5fc08b741400f0088492c9e839418b1e18522f19cba28d361dd030c5f398342"),
            .git(
                "JointDecisionv3.mlmodelc/metadata.json", size: 3453,
                blob: "0461ef9e55ba8e8ba0d2cb33b6e1a031b0d481d7"),
            .git(
                "JointDecisionv3.mlmodelc/model.mil", size: 11775,
                blob: "0a80fde4b1ec61093a03fc0fc3431172db34a4d2"),
            .lfs(
                "JointDecisionv3.mlmodelc/weights/weight.bin", size: 12_642_764,
                sha256: "4e0e63d840032f7f07ddb1d64446051166281e5491bf22da8a945c41f6eedb3e"),
            .lfs(
                "Preprocessor.mlmodelc/analytics/coremldata.bin", size: 243,
                sha256: "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d"),
            .lfs(
                "Preprocessor.mlmodelc/coremldata.bin", size: 486,
                sha256: "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d"),
            .git(
                "Preprocessor.mlmodelc/metadata.json", size: 2841,
                blob: "06162c58cf2f5343a0e60f36f843bcdf3cc58527"),
            .git(
                "Preprocessor.mlmodelc/model.mil", size: 28181,
                blob: "f987e2479228436c49189aa47edb376db74dcff5"),
            .lfs(
                "Preprocessor.mlmodelc/weights/weight.bin", size: 491_072,
                sha256: "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea"),
            .git(
                "parakeet_vocab.json", size: 151_122,
                blob: "c684822ec3b671ebc449c433a7012398d39b8bb0"),
        ],
        languages: [
            "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "it", "lt",
            "lv",
            "mt", "nl", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "uk",
        ],
        attribution:
            "Parakeet TDT 0.6B v3 by NVIDIA, CC BY 4.0 (huggingface.co/nvidia/parakeet-tdt-0.6b-v3); "
            + "Core ML conversion by FluidInference."
    )

    /// Every model, in the order the selection shows them.
    public static let all: [ModelDescriptor] = [parakeetV3]

    public static func model(id: String) -> ModelDescriptor? {
        all.first { $0.id == id }
    }
}
