import Foundation

/// Loads the transcription and cleanup models once and keeps them in memory.
///
/// Loading takes a moment — a fraction of a second each on an M1 Pro (`plans/FIRST_VERSION.md`
/// §"Status") — so the apps load them ahead of the first dictation.
@MainActor
public final class Engines {
    private let store: ModelStore
    private var transcriber: (id: String, engine: any Transcribing)?
    private var cleaner: (id: String, engine: any Cleaning)?
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

    public func cleaner(for model: ModelDescriptor) async throws -> any Cleaning {
        if let cleaner, cleaner.id == model.id { return cleaner.engine }
        try await load(model)
        guard let cleaner, cleaner.id == model.id else { throw ModelStoreError.notInstalled }
        return cleaner.engine
    }

    /// Loads a model ahead of its first use. Errors are left for the first use to report.
    public func preload(_ model: ModelDescriptor) async {
        try? await load(model)
    }

    /// Releases a loaded model, e.g. before it is deleted.
    public func unload(_ model: ModelDescriptor) {
        if transcriber?.id == model.id { transcriber = nil }
        if cleaner?.id == model.id { cleaner = nil }
    }

    /// Releases every loaded model, e.g. before the process ends: llama.cpp aborts at exit while
    /// a model still holds its Metal buffers.
    public func unloadAll() {
        transcriber = nil
        cleaner = nil
    }

    private func load(_ model: ModelDescriptor) async throws {
        if let task = loading[model.id] { return try await task.value }
        let task = Task { @MainActor in
            let folder = try await store.verifiedFolder(of: model)
            switch model.runtime {
            case .parakeet:
                transcriber = (model.id, try await ParakeetTranscriber.load(from: folder))
            case .gguf(let file):
                let loaded = try await QwenCleaner.load(from: folder.appending(path: file))
                await loaded.warmUp()
                cleaner = (model.id, loaded)
            }
        }
        loading[model.id] = task
        defer { loading[model.id] = nil }
        try await task.value
    }
}
