import Foundation
import OCIExplorerCore

public protocol OCIHTTPClientProtocol: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func upload(_ request: URLRequest, bodyData: Data, progress: @escaping @Sendable (Double) -> Void) async throws -> (Data, HTTPURLResponse)
    func download(_ request: URLRequest, to destinationURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> HTTPURLResponse
}

public final class OCIHTTPClient: NSObject, OCIHTTPClientProtocol, @unchecked Sendable {
    private final class UploadState {
        let progress: @Sendable (Double) -> Void
        let continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>
        var responseData = Data()

        init(
            progress: @escaping @Sendable (Double) -> Void,
            continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>
        ) {
            self.progress = progress
            self.continuation = continuation
        }
    }

    private final class DownloadState {
        let destinationURL: URL
        let progress: @Sendable (Double) -> Void
        let continuation: CheckedContinuation<HTTPURLResponse, Error>

        init(destinationURL: URL, progress: @escaping @Sendable (Double) -> Void, continuation: CheckedContinuation<HTTPURLResponse, Error>) {
            self.destinationURL = destinationURL
            self.progress = progress
            self.continuation = continuation
        }
    }

    private let logger: AppLogger
    private let lock = NSLock()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    private var uploadStates: [Int: UploadState] = [:]
    private var downloadStates: [Int: DownloadState] = [:]

    public init(logger: AppLogger) {
        self.logger = logger
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        await logger.log(.debug, category: "HTTP", message: "\(request.httpMethod ?? "GET") \(request.url?.path ?? "")")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network(L10n.string("error.http.non_http_response"))
        }
        try validate(httpResponse: httpResponse, data: data)
        return (data, httpResponse)
    }

    public func upload(_ request: URLRequest, bodyData: Data, progress: @escaping @Sendable (Double) -> Void) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.httpBody = nil
        let taskBox = TaskBox<URLSessionUploadTask>()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.uploadTask(with: request, from: bodyData)
                taskBox.value = task
                let state = UploadState(progress: progress, continuation: continuation)
                lock.lock()
                uploadStates[task.taskIdentifier] = state
                lock.unlock()
                progress(0)
                task.resume()
            }
        }, onCancel: {
            taskBox.value?.cancel()
        })
    }

    public func download(_ request: URLRequest, to destinationURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> HTTPURLResponse {
        let taskBox = TaskBox<URLSessionDownloadTask>()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.downloadTask(with: request)
                taskBox.value = task
                lock.lock()
                downloadStates[task.taskIdentifier] = DownloadState(destinationURL: destinationURL, progress: progress, continuation: continuation)
                lock.unlock()
                task.resume()
            }
        }, onCancel: {
            taskBox.value?.cancel()
        })
    }

    private func validate(httpResponse: HTTPURLResponse, data: Data) throws {
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? L10n.string("error.http.empty_body")
            throw AppError.network(L10n.string("error.http.status", httpResponse.statusCode, body))
        }
    }
}

extension OCIHTTPClient: URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        lock.lock()
        let state = uploadStates[task.taskIdentifier]
        lock.unlock()
        state?.progress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        let uploadState = uploadStates[dataTask.taskIdentifier]
        lock.unlock()
        uploadState?.responseData.append(data)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        lock.lock()
        let state = downloadStates[downloadTask.taskIdentifier]
        lock.unlock()
        state?.progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        lock.lock()
        let state = downloadStates[downloadTask.taskIdentifier]
        lock.unlock()

        guard let state else { return }
        do {
            let fileManager = FileManager.default
            let destinationDir = state.destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: destinationDir.path) {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: state.destinationURL.path) {
                try fileManager.removeItem(at: state.destinationURL)
            }
            try fileManager.moveItem(at: location, to: state.destinationURL)
        } catch {
            state.continuation.resume(throwing: AppError.storage(L10n.string("error.http.download_save_failed", error.localizedDescription)))
            lock.lock()
            downloadStates.removeValue(forKey: downloadTask.taskIdentifier)
            lock.unlock()
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let uploadState = uploadStates.removeValue(forKey: task.taskIdentifier)
        let downloadState = downloadStates.removeValue(forKey: task.taskIdentifier)
        lock.unlock()

        if let error {
            uploadState?.continuation.resume(throwing: AppError.from(error))
            downloadState?.continuation.resume(throwing: AppError.from(error))
            return
        }

        guard let httpResponse = task.response as? HTTPURLResponse else {
            let error = AppError.network(L10n.string("error.http.transfer_non_http"))
            uploadState?.continuation.resume(throwing: error)
            downloadState?.continuation.resume(throwing: error)
            return
        }

        if let uploadState {
            do {
                try validate(httpResponse: httpResponse, data: uploadState.responseData)
                uploadState.progress(1)
                uploadState.continuation.resume(returning: (uploadState.responseData, httpResponse))
            } catch {
                uploadState.continuation.resume(throwing: error)
            }
        }

        if let downloadState {
            do {
                try validate(httpResponse: httpResponse, data: Data())
                downloadState.continuation.resume(returning: httpResponse)
            } catch {
                downloadState.continuation.resume(throwing: error)
            }
        }
    }
}

private final class TaskBox<TaskType>: @unchecked Sendable {
    var value: TaskType?
}
