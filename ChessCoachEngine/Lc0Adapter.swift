import Foundation
import Combine

// MARK: - Lc0Adapter

/// UCI-like adapter for Leela Chess Zero (Lc0).
/// FUTURE: Lc0 uses a REST API + UCI bridge (lc0-http) rather than native UCI,
/// so this stub documents the integration points needed when the bridge exists.
///
/// Leela uses the UCI protocol but with extensions:
/// - `uci` → `uciok`
/// - `isready` → `readyok`
/// - `position ...` and `go ...` work the same as Stockfish
/// - Lc0 outputs `info depth N ... score cp/povcp M ... pv ...` lines
///
/// For iOS, the recommended path is the lc0-http server bundled with the app,
/// which exposes the engine via a local HTTP+WebSocket API. This adapter
/// would then use URLSession to communicate with that server rather than a
/// local Process.
public final class Lc0Adapter: ChessEngine, @unchecked Sendable {
    public let displayName = "Lc0 (Leela Chess Zero)"
    public private(set) var isAvailable = false

    private var serverURL: URL?
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var outputSubject = PassthroughSubject<String, Never>()
    private var analysisCancellable: AnyCancellable?
    private var currentDepth: Int?

    public private(set) var lastBestMove: String?

    public init() {}

    // MARK: - ChessEngine

    public func initialize() async throws {
        // TODO: Check for lc0-http server binary or bundled weights
        // Lc0 weights file (~30MB for the 256x10-se network) should be
        // bundled as an asset or downloaded from:
        // https://lczero.org/files/256x10.pb
        //
        // The lc0-http server binary for macOS/iOS can be obtained from:
        // https://github.com/fsmosca/lc0-http-server/releases
        //
        // Integration steps when lc0-http is available:
        // 1. Start the server process (lc0-http --backend=cuda --weights=256x10.pb)
        // 2. Connect via WebSocket to http://localhost:5678/api/v1/analyze
        // 3. POST {"fen": "<fen>", "depth": <depth>} to start analysis
        // 4. Read SSE stream for info lines and parse as EngineLine

        isAvailable = false
        throw EngineError.notAvailable
    }

    public func startAnalysis(fen: String, depth: Int?, timeout: TimeInterval?) -> AnyPublisher<EngineLine, Never> {
        let subject = PassthroughSubject<EngineLine, Never>()
        // When lc0-http is integrated, translate UCI output to EngineLine here
        return subject.eraseToAnyPublisher()
    }

    public func stopAnalysis() {
        analysisCancellable?.cancel()
        analysisCancellable = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    public func shutdown() {
        stopAnalysis()
        webSocketTask = nil
        session = nil
    }
}
