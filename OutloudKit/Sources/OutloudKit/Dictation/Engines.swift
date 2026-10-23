import Foundation

/// Loads the transcription model once and keeps it in memory. The cleanup needs no loading: it
/// runs on Apple's on-device model (ADR 0019).
///
/// Loading takes a moment — a fraction of a second on an M1 Pro (`plans/FIRST_VERSION.md`
/// §"Status") — so the apps load it ahead of the first dictation.
@MainActor
public final class Engines {
    private let store: ModelStore
    private var transcriber: (id: String, engine: any Transcribing)?
    private var loading: [String: Task<Void, Error>] = [:]

    public init(store: ModelStore) {
        self.store = store
    }

    public func transcriber(for model: ModelDescriptor) async throws -> any Transcribing {
        if let transcriber, transcriber.id == model.id { return transcriber.engine }
        try await load(model)
        guard let transcriber, transcriber.id == model.id else {
            throw ModelStoreError.notInstalled
        }
        return transcriber.engine
    }

    /// Loads a model ahead of its first use. Errors are left for the first use to report.
    public func preload(_ model: ModelDescriptor) async {
        try? await load(model)
    }

    /// Releases a loaded model, e.g. before it is deleted.
    public func unload(_ model: ModelDescriptor) {
        if transcriber?.id == model.id { transcriber = nil }
    }

    private func load(_ model: ModelDescriptor) async throws {
        if let task = loading[model.id] { return try await task.value }
        let task = Task { @MainActor in
            let folder = try await store.verifiedFolder(of: model)
            transcriber = (model.id, try await ParakeetTranscriber.load(from: folder))
        }
        loading[model.id] = task
        defer { loading[model.id] = nil }
        try await task.value
    }
}
