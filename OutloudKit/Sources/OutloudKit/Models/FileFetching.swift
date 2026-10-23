import Foundation

/// Downloads one file to a destination, reporting the bytes written so far.
public protocol FileFetching: Sendable {
    func fetch(
        _ url: URL, to destination: URL, progress: @escaping @Sendable (Int64) -> Void
    ) async throws
}

public enum FileFetchingError: Error, Equatable, Sendable {
    case httpStatus(Int)
}

/// Fetches with a download task, so a large file streams to disk instead of into memory.
public struct URLSessionFileFetcher: FileFetching {
    private let configuration: URLSessionConfiguration

    public init(configuration: URLSessionConfiguration = .default) {
        self.configuration = configuration
    }

    public func fetch(
        _ url: URL, to destination: URL, progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        let delegate = DownloadDelegate(destination: destination, progress: progress)
        let session = URLSession(
            configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.start(session.downloadTask(with: url), continuation: continuation)
            }
        } onCancel: {
            delegate.cancel()
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let progress: @Sendable (Int64) -> Void
    private let lock = NSLock()
    // Guarded by `lock`.
    private var task: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<Void, Error>?
    private var failure: Error?
    private var cancelled = false

    init(destination: URL, progress: @escaping @Sendable (Int64) -> Void) {
        self.destination = destination
        self.progress = progress
    }

    func start(_ task: URLSessionDownloadTask, continuation: CheckedContinuation<Void, Error>) {
        let isCancelled = lock.withLock {
            self.task = task
            self.continuation = continuation
            return cancelled
        }
        if isCancelled { task.cancel() } else { task.resume() }
    }

    func cancel() {
        let task = lock.withLock {
            cancelled = true
            return self.task
        }
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        progress(totalBytesWritten)
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // The temporary file is gone once this method returns, so it is moved here.
        if let response = downloadTask.response as? HTTPURLResponse,
            !(200..<300).contains(response.statusCode)
        {
            lock.withLock { failure = FileFetchingError.httpStatus(response.statusCode) }
            return
        }
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
        } catch {
            lock.withLock { failure = error }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        let (continuation, failure) = lock.withLock {
            let pending = self.continuation
            self.continuation = nil
            return (pending, self.failure)
        }
        if cancelled(error) {
            continuation?.resume(throwing: CancellationError())
        } else if let error = error ?? failure {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }

    private func cancelled(_ error: Error?) -> Bool {
        (error as? URLError)?.code == .cancelled && lock.withLock { cancelled }
    }
}
