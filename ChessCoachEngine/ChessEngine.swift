import Foundation
import Combine

// MARK: - ChessEngine

/// Protocol for chess engine adapters (Stockfish, Lc0, etc.)
public protocol ChessEngine: AnyObject {
    /// Display name for the engine
    var displayName: String { get }

    /// Whether the engine binary is available / loaded
    var isAvailable: Bool { get }

    /// Initialize the engine. Call after object creation.
    func initialize() async throws

    /// Start analysing a position.
    /// - Parameters:
    ///   - fen: FEN string of the position
    ///   - depth: Maximum search depth (nil = infinite until stop)
    ///   - timeout: Maximum time to search in seconds (nil = controlled by depth)
    func startAnalysis(fen: String, depth: Int?, timeout: TimeInterval?) -> AnyPublisher<EngineLine, Never>

    /// Stop the current analysis
    func stopAnalysis()

    /// Best move from the last analysis run (available after stopAnalysis)
    var lastBestMove: String? { get }

    /// Shutdown the engine process
    func shutdown()
}

// MARK: - EngineError

public enum EngineError: Error, LocalizedError {
    case notAvailable
    case initializationFailed(String)
    case processError(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notAvailable: return "Engine binary not found"
        case .initializationFailed(let msg): return "Engine init failed: \(msg)"
        case .processError(let msg): return "Engine process error: \(msg)"
        case .timeout: return "Engine analysis timed out"
        }
    }
}

// MARK: - Default implementation helpers

public extension ChessEngine {
    /// Default observable publisher for analysis.
    /// Engines override this if they need custom behaviour.
    func startAnalysis(fen: String, depth: Int?, timeout: TimeInterval?) -> AnyPublisher<EngineLine, Never> {
        startAnalysis(fen: fen, depth: depth, timeout: timeout)
    }
}
