import Foundation

// MARK: - ModelDownloadService

/// Manages GGUF model download, storage, and version tracking.
public actor ModelDownloadService {

    public enum DownloadState: Equatable {
        case notStarted
        case downloading(progress: Double) // 0.0 - 1.0
        case downloaded
        case failed(String)
    }

    public enum DownloadError: Error, LocalizedError {
        case invalidURL
        case networkError(Int)
        case writeError(String)
        case insufficientStorage

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid download URL"
            case .networkError(let code): return "Network error: \(code)"
            case .writeError(let msg): return "Write error: \(msg)"
            case .insufficientStorage: return "Not enough storage space"
            }
        }
    }

    private let fileManager = FileManager.default
    private var downloadTask: URLSessionDownloadTask?

    public init() {}

    // MARK: - Paths

    public nonisolated var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Models", isDirectory: true)
    }

    public nonisolated func modelPath(for config: ModelConfig) -> URL {
        return modelsDirectory.appendingPathComponent(config.fileName)
    }

    // MARK: - Status

    public func isModelDownloaded(_ config: ModelConfig) -> Bool {
        return fileManager.fileExists(atPath: modelPath(for: config).path)
    }

    public func downloadState(for config: ModelConfig) -> DownloadState {
        if isModelDownloaded(config) {
            return .downloaded
        }
        return .notStarted
    }

    // MARK: - Download

    /// Downloads the GGUF file. Calls progressHandler periodically with 0.0-1.0 values.
    public func downloadModel(
        _ config: ModelConfig,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        guard let url = URL(string: config.downloadURL) else {
            throw DownloadError.invalidURL
        }

        // Check available space (need at least 2x model size for safety)
        let attrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
        let freeSpace = (attrs?[.systemFreeSize] as? Int64) ?? 0
        let requiredSpace = Int64(config.bundleSizeMB) * 1024 * 1024 * 2
        if freeSpace < requiredSpace {
            throw DownloadError.insufficientStorage
        }

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let (tempURL, response) = try await session.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DownloadError.networkError(code)
        }

        let destination = modelPath(for: config)

        // Remove existing file if present
        try? fileManager.removeItem(at: destination)

        try fileManager.moveItem(at: tempURL, to: destination)
        progressHandler(1.0)
    }

    /// Cancels an in-progress download.
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
    }

    /// Deletes a downloaded model.
    public func deleteModel(_ config: ModelConfig) throws {
        let path = modelPath(for: config)
        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
        }
    }

    /// Returns the total size of downloaded models on disk.
    public func downloadedModelsSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return contents.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }
}

// MARK: - ModelStorageInfo

public struct ModelStorageInfo {
    public let config: ModelConfig
    public let downloaded: Bool
    public let fileSizeBytes: Int64?
    public let downloadState: ModelDownloadService.DownloadState

    public var fileSizeMB: Int? {
        guard let s = fileSizeBytes else { return nil }
        return Int(s / 1024 / 1024)
    }
}
