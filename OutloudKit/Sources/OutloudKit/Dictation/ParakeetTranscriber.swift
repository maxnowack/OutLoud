import FluidAudio
import Foundation

/// Transcribes with Parakeet v3 through FluidAudio (ADR 0006). The language is detected by the
/// model; German and English need no setting.
public actor ParakeetTranscriber: Transcribing {
    private let manager: AsrManager

    private init(manager: AsrManager) {
        self.manager = manager
    }

    /// Loads the model from its snapshot folder in the hub cache. Never downloads: FluidAudio's
    /// own downloader stays off, since `ModelStore` owns the model files.
    public static func load(from folder: URL) async throws -> ParakeetTranscriber {
        ModelHub.offlineMode = true
        let models = try AsrModels.loadLocal(from: folder, version: .v3)
        return ParakeetTranscriber(manager: AsrManager(config: .default, models: models))
    }

    public func transcribe(_ samples: [Float]) async throws -> String {
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(samples, decoderState: &state).text
    }
}
