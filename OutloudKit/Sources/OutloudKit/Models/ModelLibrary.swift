import Foundation
import Observation

/// The state of one model on this device.
public enum ModelState: Equatable, Sendable {
    case notInstalled
    case downloading(completed: Int64, total: Int64)
    case installed
    case failed(String)

    public var isInstalled: Bool { self == .installed }

    public var isDownloading: Bool {
        if case .downloading = self { true } else { false }
    }

    /// The share of the download that is done, 0 to 1, while downloading.
    public var fraction: Double? {
        guard case .downloading(let completed, let total) = self, total > 0 else { return nil }
        return Double(completed) / Double(total)
    }
}

/// The models and their states, for the first launch and the settings (`docs/SPEC.md` §"Models").
@MainActor
@Observable
public final class ModelLibrary {
    public let store: ModelStore
    public private(set) var states: [ModelDescriptor.ID: ModelState] = [:]
    @ObservationIgnored private var downloads: [ModelDescriptor.ID: Task<Void, Never>] = [:]
    @ObservationIgnored private var lastReport: [ModelDescriptor.ID: ContinuousClock.Instant] = [:]

    /// Called after a model was deleted, so that a loaded copy is released.
    @ObservationIgnored public var onDelete: ((ModelDescriptor) -> Void)?

    public init(store: ModelStore) {
        self.store = store
        for model in ModelCatalog.all { states[model.id] = .notInstalled }
    }

    public func state(of model: ModelDescriptor) -> ModelState {
        states[model.id] ?? .notInstalled
    }

    /// Reads which models are complete in the cache. Another tool may have added or removed
    /// files since the last look.
    public func refresh() async {
        for model in ModelCatalog.all where !state(of: model).isDownloading {
            states[model.id] = await store.isInstalled(model) ? .installed : .notInstalled
        }
    }

    /// The bytes still to download for the models.
    public func missingBytes(of models: [ModelDescriptor]) async -> Int64 {
        var total: Int64 = 0
        for model in models { total += await store.missingBytes(of: model) }
        return total
    }

    /// Starts downloading a model; the state follows its progress.
    public func download(_ model: ModelDescriptor) {
        guard downloads[model.id] == nil else { return }
        states[model.id] = .downloading(completed: 0, total: model.totalSize)
        let store = self.store
        // The library lives as long as the app, so the task holds it strongly.
        downloads[model.id] = Task {
            do {
                try await store.download(model) { completed, total in
                    Task { @MainActor in self.report(model, completed: completed, total: total) }
                }
                _ = try await store.verifiedFolder(of: model)
                finish(model, state: .installed)
            } catch is CancellationError {
                finish(model, state: .notInstalled)
            } catch {
                finish(model, state: .failed(Self.describe(error)))
            }
        }
    }

    /// Downloads every model that is not installed yet and waits for them.
    public func downloadAll(_ models: [ModelDescriptor]) async {
        for model in models where !state(of: model).isInstalled { download(model) }
        for model in models { await downloads[model.id]?.value }
    }

    public func cancelDownload(_ model: ModelDescriptor) {
        downloads[model.id]?.cancel()
    }

    public func delete(_ model: ModelDescriptor) async throws {
        cancelDownload(model)
        await downloads[model.id]?.value
        onDelete?(model)
        try await store.delete(model)
        states[model.id] = .notInstalled
    }

    private func report(_ model: ModelDescriptor, completed: Int64, total: Int64) {
        guard downloads[model.id] != nil else { return }
        // Progress arrives for every few kilobytes; the interface needs a few updates a second.
        let now = ContinuousClock.now
        if let last = lastReport[model.id], now - last < .milliseconds(100), completed < total {
            return
        }
        lastReport[model.id] = now
        states[model.id] = .downloading(completed: completed, total: total)
    }

    private func finish(_ model: ModelDescriptor, state: ModelState) {
        downloads[model.id] = nil
        lastReport[model.id] = nil
        states[model.id] = state
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case ModelStoreError.insufficientSpace(let needed, let available):
            let formatter = ByteCountFormatter()
            return String(
                localized:
                    "Not enough space: \(formatter.string(fromByteCount: needed)) needed, \(formatter.string(fromByteCount: available)) free.",
                bundle: .module)
        case ModelStoreError.hashMismatch:
            return String(
                localized: "A downloaded file was damaged. Please try again.", bundle: .module)
        case FileFetchingError.httpStatus(let status):
            return String(localized: "The download failed (HTTP \(status)).", bundle: .module)
        case let error as URLError where error.code == .notConnectedToInternet:
            return String(localized: "There is no internet connection.", bundle: .module)
        default:
            return error.localizedDescription
        }
    }
}
