import Foundation

// MARK: - ModelDownloadService

/// Manages GGUF model storage — checks the app bundle first (self-contained),
/// then falls back to Documents/ for downloaded models.
public actor ModelDownloadService {

    public enum DownloadState: Equatable {
        case notStarted
        case downloading(progress: Double) // 0.0 - 1.0
        case downloaded
        case failed(String)

        public var isDownloaded: Bool {
            if case .downloaded = self { return true }
            return false
        }
    }

    public enum DownloadError: Error, LocalizedError {
        case invalidURL
        case networkError(Int)
        case writeError(String)
        case insufficientStorage
        case bundleModelNotFound

        public var errorDescription: String? {
            switch self {
            case .invalidURL:           return "Invalid download URL"
            case .networkError(let code): return "Network error: \(code)"
            case .writeError(let msg):  return "Write error: \(msg)"
            case .insufficientStorage: return "Not enough storage space"
            case .bundleModelNotFound:  return "Bundled model not found in app bundle"
            }
        }
    }

    private let fileManager = FileManager.default
    private var downloadTask: URLSessionDownloadTask?

    public init() {}

    // MARK: - Paths

    /// Subdirectory within the app bundle where GGUF models are stored.
    /// Matches the directory path in the Xcode project: ChessCoachShared/Models/
    private nonisolated var bundleSubdirectory: String {
        "Models"
    }

    /// True if the model is bundled inside the app binary (not downloaded).
    public nonisolated func isBundled(_ config: ModelConfig) -> Bool {
        Bundle.main.url(
            forResource: config.fileName.replacingOccurrences(of: ".gguf", with: ""),
            withExtension: "gguf",
            subdirectory: bundleSubdirectory
        ) != nil
    }

    /// Resolved path to the model — bundle first, then Documents/.
    /// The returned URL is guaranteed to be valid if the model exists.
    public nonisolated func modelPath(for config: ModelConfig) -> URL {
        // 1. Check bundle
        if let bundleURL = Bundle.main.url(
            forResource: config.fileName.replacingOccurrences(of: ".gguf", with: ""),
            withExtension: "gguf",
            subdirectory: bundleSubdirectory
        ) {
            return bundleURL
        }

        // 2. Fall back to Documents
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Models").appendingPathComponent(config.fileName)
    }

    /// Documents-only path (used for downloaded models, never bundle).
    public nonisolated var modelsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models", isDirectory: true)
    }

    // MARK: - Status

    public func isModelDownloaded(_ config: ModelConfig) -> Bool {
        if isBundled(config) { return true }
        return fileManager.fileExists(atPath: modelPath(for: config).path)
    }

    public func downloadState(for config: ModelConfig) -> DownloadState {
        if isBundled(config) { return .downloaded }
        if isModelDownloaded(config) { return .downloaded }
        return .notStarted
    }

    // MARK: - Download

    /// Downloads the GGUF file. Calls progressHandler periodically with 0.0-1.0 values.
    /// Skips download entirely if the model is already bundled.
    public func downloadModel(
        _ config: ModelConfig,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        // Already bundled — nothing to download
        if isBundled(config) {
            progressHandler(1.0)
            return
        }

        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        guard let url = URL(string: config.downloadURL) else {
            throw DownloadError.invalidURL
        }

        // Check available space
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
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: tempURL, to: destination)
        progressHandler(1.0)
    }

    /// Cancels an in-progress download.
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
    }

    /// Deletes a downloaded model (no-op for bundled models).
    public func deleteModel(_ config: ModelConfig) throws {
        if isBundled(config) { return }
        let path = modelPath(for: config)
        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
        }
    }

    /// Total size of downloaded models on disk (excludes bundle).
    public func downloadedModelsSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
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
    public let bundled: Bool
    public let fileSizeBytes: Int64?
    public let downloadState: ModelDownloadService.DownloadState

    public var fileSizeMB: Int? {
        guard let s = fileSizeBytes else { return nil }
        return Int(s / 1024 / 1024)
    }
}
