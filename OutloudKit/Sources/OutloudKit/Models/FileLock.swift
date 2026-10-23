import Foundation

/// An exclusive advisory lock on a file, as the hub's own tools take one per blob while writing it.
final class FileLock: Sendable {
    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    /// Waits until no other process holds the lock. Polls, so that a waiting task stays
    /// cancellable and does not block a thread.
    static func acquire(at url: URL) async throws -> FileLock {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                close(descriptor)
                throw error
            }
        }
        return FileLock(descriptor: descriptor)
    }

    func release() {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
