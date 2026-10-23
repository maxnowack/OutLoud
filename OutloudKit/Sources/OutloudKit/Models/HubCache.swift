import Foundation

/// The Hugging Face hub cache layout (ADR 0010; `OutloudKit/AGENTS.md` §"The Hugging Face cache").
///
/// One folder per repository, `models--<organisation>--<name>`, holds the files by hash in
/// `blobs/` and per revision as relative symlinks in `snapshots/<commit>/`. Writers lock per file
/// under `<root>/.locks/models--<organisation>--<name>/<etag>.lock`.
public struct HubCache: Sendable, Hashable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    #if os(macOS)
        /// The cache the hub's own tools use: `HF_HUB_CACHE`, else `HF_HOME/hub`, else
        /// `~/.cache/huggingface/hub`.
        public static func shared(
            environment: [String: String] = ProcessInfo.processInfo.environment,
            home: URL = FileManager.default.homeDirectoryForCurrentUser
        ) -> HubCache {
            if let path = environment["HF_HUB_CACHE"], !path.isEmpty {
                return HubCache(root: URL(filePath: expandingTilde(path, home: home)))
            }
            if let path = environment["HF_HOME"], !path.isEmpty {
                return HubCache(
                    root: URL(filePath: expandingTilde(path, home: home)).appending(path: "hub"))
            }
            return HubCache(root: home.appending(path: ".cache/huggingface/hub"))
        }

        private static func expandingTilde(_ path: String, home: URL) -> String {
            guard path.hasPrefix("~") else { return path }
            return home.path(percentEncoded: false) + path.dropFirst()
        }
    #endif

    /// A cache in the app's own container, where apps of different vendors cannot share models
    /// (iOS; ADR 0009).
    public static func appContainer(fileManager: FileManager = .default) throws -> HubCache {
        let support = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
        return HubCache(root: support.appending(path: "Models/huggingface/hub"))
    }

    func folderName(of repository: String) -> String {
        "models--" + repository.replacingOccurrences(of: "/", with: "--")
    }

    public func repositoryFolder(of repository: String) -> URL {
        root.appending(path: folderName(of: repository), directoryHint: .isDirectory)
    }

    public func snapshotFolder(of model: ModelDescriptor) -> URL {
        repositoryFolder(of: model.repository)
            .appending(path: "snapshots/\(model.revision)", directoryHint: .isDirectory)
    }

    func snapshotFile(_ file: ModelFile, of model: ModelDescriptor) -> URL {
        snapshotFolder(of: model).appending(path: file.path)
    }

    func blob(_ file: ModelFile, of model: ModelDescriptor) -> URL {
        repositoryFolder(of: model.repository).appending(path: "blobs/\(file.hash.etag)")
    }

    func lock(_ file: ModelFile, of model: ModelDescriptor) -> URL {
        root.appending(path: ".locks/\(folderName(of: model.repository))/\(file.hash.etag).lock")
    }

    func downloadURL(_ file: ModelFile, of model: ModelDescriptor) -> URL {
        URL(string: "https://huggingface.co/\(model.repository)/resolve/\(model.revision)")!
            .appending(path: file.path)
    }
}
