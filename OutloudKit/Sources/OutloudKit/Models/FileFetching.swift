import Foundation

/// Downloads one file to a destination, reporting the bytes written so far.
public protocol FileFetching: Sendable {
    /// - Parameter overCellular: Whether the user allowed the download over cellular data; when
    ///   not, it waits for Wi-Fi instead of switching to cellular data (`docs/SPEC.md` §"Models").
    func fetch(
        _ url: URL, to destination: URL, overCellular: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws

    /// The files still being downloaded from an earlier run of the app, which `fetch` picks up
    /// instead of starting them again.
    func activeDownloads() async -> [URL]
}

extension FileFetching {
    public func activeDownloads() async -> [URL] { [] }
}

public enum FileFetchingError: Error, Equatable, Sendable {
    case httpStatus(Int)
}

/// Fetches with download tasks of one session, so that a large file streams to disk instead of
/// into memory.
///
/// With a background configuration, iOS goes on downloading while the app is suspended or was
/// ended, and hands the file over when the app runs again (`plans/BACKGROUND_DICTATION.md`).
/// Each task carries its destination in its description, so that a file that finished while no
/// `fetch` was waiting for it still lands where the store looks for it.
public final class URLSessionFileFetcher: NSObject, FileFetching, URLSessionDownloadDelegate,
    @unchecked Sendable
{
    private let configuration: URLSessionConfiguration
    private let lock = NSLock()
    // Guarded by `lock`.
    private var openSession: URLSession?
    private var handlers: [Int: DownloadHandler] = [:]
    private var backgroundEventsDone: (@MainActor () -> Void)?
    /// The session finished its background events before the app handed over `done`.
    private var backgroundEventsFinished = false

    public init(configuration: URLSessionConfiguration = .default) {
        self.configuration = configuration
    }

    /// A fetcher whose downloads go on while the app is in the background.
    public static func background(identifier: String) -> URLSessionFileFetcher {
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        let fetcher = URLSessionFileFetcher(configuration: configuration)
        // Reconnects to the system's session at once, so that downloads that finished while the
        // app was not running are delivered.
        _ = fetcher.session
        return fetcher
    }

    /// Called by the app when iOS woke it for this session's events; `done` is called once they
    /// are handled.
    public func handleBackgroundEvents(_ done: @escaping @MainActor () -> Void) {
        let finished = lock.withLock {
            defer { backgroundEventsFinished = false }
            if !backgroundEventsFinished { backgroundEventsDone = done }
            return backgroundEventsFinished
        }
        if finished { Task { @MainActor in done() } }
    }

    private var session: URLSession {
        lock.withLock {
            if let openSession { return openSession }
            let session = URLSession(
                configuration: configuration, delegate: self, delegateQueue: nil)
            openSession = session
            return session
        }
    }

    public func activeDownloads() async -> [URL] {
        await session.allTasks.filter { $0.state == .running || $0.state == .suspended }
            .compactMap { $0.originalRequest?.url }
    }

    public func fetch(
        _ url: URL, to destination: URL, overCellular: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws {
        let session = self.session
        let running = await session.allTasks.first {
            $0.originalRequest?.url == url && ($0.state == .running || $0.state == .suspended)
        }
        var request = URLRequest(url: url)
        request.allowsExpensiveNetworkAccess = overCellular
        let task = (running as? URLSessionDownloadTask) ?? session.downloadTask(with: request)
        task.taskDescription = Self.describe(destination)
        let handler = DownloadHandler(destination: destination, progress: progress)
        lock.withLock { handlers[task.taskIdentifier] = handler }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                handler.start(task, continuation: continuation)
                // A task picked up from an earlier run may have finished before the handler was
                // registered; its completion is not delivered again.
                if task.state == .completed {
                    lock.withLock { handlers[task.taskIdentifier] = nil }
                    if let failure = Self.failure(of: task) { handler.fail(failure) }
                    handler.complete(task.error)
                }
            }
        } onCancel: {
            handler.cancel()
        }
    }

    private func handler(for task: URLSessionTask) -> DownloadHandler? {
        lock.withLock { handlers[task.taskIdentifier] }
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        handler(for: downloadTask)?.progress(totalBytesWritten)
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // The temporary file is gone once this method returns, so it is moved here.
        let failure: Error?
        if let status = Self.failure(of: downloadTask) {
            failure = status
        } else if let destination = downloadTask.taskDescription.flatMap(Self.resolve) {
            failure = Self.move(location, to: destination)
        } else {
            failure = nil
        }
        if let failure { handler(for: downloadTask)?.fail(failure) }
    }

    public func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        let handler = lock.withLock { handlers.removeValue(forKey: task.taskIdentifier) }
        handler?.complete(error)
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let done = lock.withLock {
            defer { backgroundEventsDone = nil }
            if backgroundEventsDone == nil { backgroundEventsFinished = true }
            return backgroundEventsDone
        }
        if let done { Task { @MainActor in done() } }
    }

    private static func failure(of task: URLSessionTask) -> Error? {
        guard let response = task.response as? HTTPURLResponse,
            !(200..<300).contains(response.statusCode)
        else { return nil }
        return FileFetchingError.httpStatus(response.statusCode)
    }

    /// The destination as the task keeps it: relative to the home folder when it lies inside,
    /// since an iOS app's container moves, e.g. with an update, while a download goes on.
    static func describe(_ destination: URL) -> String {
        let home = URL(filePath: NSHomeDirectory()).standardizedFileURL.path + "/"
        let path = destination.standardizedFileURL.path
        return path.hasPrefix(home) ? "~/" + path.dropFirst(home.count) : path
    }

    static func resolve(_ description: String) -> URL? {
        guard description.hasPrefix("~/") else {
            return description.hasPrefix("/") ? URL(filePath: description) : nil
        }
        return URL(filePath: NSHomeDirectory()).appending(path: String(description.dropFirst(2)))
    }

    private static func move(_ location: URL, to destination: URL) -> Error? {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
            return nil
        } catch {
            return error
        }
    }
}

/// One `fetch` waiting for its task.
private final class DownloadHandler: @unchecked Sendable {
    let destination: URL
    let progress: @Sendable (Int64) -> Void
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

    func fail(_ error: Error) {
        lock.withLock { failure = error }
    }

    func complete(_ error: Error?) {
        let (continuation, failure, cancelled) = lock.withLock {
            let pending = self.continuation
            self.continuation = nil
            return (pending, self.failure, self.cancelled)
        }
        if cancelled, (error as? URLError)?.code == .cancelled {
            continuation?.resume(throwing: CancellationError())
        } else if let error = error ?? failure {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}
