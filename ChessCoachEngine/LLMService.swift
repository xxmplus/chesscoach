import Foundation
import ChessCoachShared
import ChessCoachEngine

// MARK: - LLMService

/// Protocol for local LLM inference services that generate coaching text.
public protocol LLMService: AnyObject, Sendable {
    /// Whether the model is loaded and ready for inference.
    nonisolated var isReady: Bool { get }

    /// Load the GGUF model into memory. Idempotent.
    func loadModel() async throws

    /// Unload the model and free GPU/CPU memory.
    func unloadModel() async

    /// Generate a coaching message from structured engine analysis.
    func generateCoachingText(
        from prompt: LLMCoachingPrompt
    ) async throws -> String
}

// MARK: - LLMError

public enum LLMError: Error, LocalizedError, Sendable {
    case modelNotLoaded
    case generationFailed(String)
    case modelLoadFailed(String)
    case timeout
    case cancelled
    case notSupported

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:     return "Model not loaded"
        case .generationFailed(let msg): return "Generation failed: \(msg)"
        case .modelLoadFailed(let msg):  return "Model load failed: \(msg)"
        case .timeout:            return "Generation timed out"
        case .cancelled:          return "Generation cancelled"
        case .notSupported:       return "LLM inference not supported on this device"
        }
    }
}

// MARK: - LLMCoachingPrompt

/// Structured data fed to the LLM as a prompt.
public struct LLMCoachingPrompt: Sendable {
    public let score: EngineScore
    public let bestMove: String
    public let alternatives: [(move: String, score: EngineScore)]
    public let playerColor: PieceColor

    public init(
        score: EngineScore,
        bestMove: String,
        alternatives: [(move: String, score: EngineScore)],
        playerColor: PieceColor
    ) {
        self.score = score
        self.bestMove = bestMove
        self.alternatives = alternatives
        self.playerColor = playerColor
    }

    /// Formats as a prompt string for chat-template LLMs.
    public var promptString: String {
        let scoreStr: String
        switch score {
        case .cp(let cp):
            let sign = cp >= 0 ? "+" : ""
            scoreStr = "\(sign)\(String(format: "%.2f", Double(cp) / 100.0)) pawns"
        case .mate(let plies):
            scoreStr = plies > 0 ? "mate in \(plies)" : "mate in \(abs(plies)) (for opponent)"
        default:
            scoreStr = "unknown"
        }

        let colorStr = playerColor == .white ? "White" : "Black"
        var altStr = ""
        if !alternatives.isEmpty {
            let alts = alternatives.prefix(3).map { alt in
                let evalStr: String
                switch alt.score {
                case .cp(let cp): evalStr = "\(cp >= 0 ? "+" : "")\(String(format: "%.2f", Double(cp) / 100.0))"
                case .mate(let pl): evalStr = "M\(pl)"
                default: evalStr = "?"
                }
                return "\(alt.move) (\(evalStr))"
            }.joined(separator: ", ")
            altStr = " alternatives: \(alts)."
        }

        return """
        You are a friendly chess coach for beginners. Parse this engine analysis and give a 2-sentence coaching tip.

        Engine analysis:
        - \(colorStr) to move, advantage: \(scoreStr)
        - Best move: \(bestMove)\(altStr)

        Write exactly 2 sentences. Be encouraging. No chess jargon. Coach tip:
        """
    }
}
