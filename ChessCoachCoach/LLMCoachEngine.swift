import Foundation
import ChessCoachShared
import ChessCoachEngine

// MARK: - LLMCoachEngine

/// A coach engine that uses a local LLM (Qwen2.5-3B or SmolLM2) to generate
/// natural language explanations from structured engine analysis.
public final class LLMCoachEngine: @unchecked Sendable {

    private let llmService: any LLMService
    private let templateEngine: CoachEngine
    private let modelConfig: ModelConfig
    private let serverManager: (any LLMServerManager)?

    public var isReady: Bool {
        llmService.isReady
    }

    public init(
        modelConfig: ModelConfig = .deepseekR1_Qwen_1_5B,
        llmService: any LLMService,
        serverManager: (any LLMServerManager)? = nil
    ) {
        self.llmService = llmService
        self.templateEngine = CoachEngine()
        self.modelConfig = modelConfig
        self.serverManager = serverManager
    }

    // MARK: - Lifecycle

    /// Start the LLM server and load the model.
    public func start() async throws {
        if let manager = serverManager {
            let modelPath = ModelDownloadService().modelPath(for: modelConfig).path
            _ = try await manager.start(modelPath: modelPath)
        }
        try await llmService.loadModel()
    }

    /// Stop the LLM server and free memory.
    public func stop() async {
        if let manager = serverManager {
            await manager.stop()
        }
        await llmService.unloadModel()
    }

    // MARK: - Generate

    /// Generate a full coaching explanation for a move.
    public func generateMoveExplanation(
        move: Move,
        position: Position,
        engineEval: EngineLine,
        engineCandidates: [EngineLine],
        bestMove: Move?
    ) async -> [CoachMessage] {
        let quality = templateEngine.classifyMove(move: move, position: position, engineEval: engineEval)
        var messages: [CoachMessage] = []

        // 1. Quality verdict from template engine
        messages.append(verdictMessage(quality: quality, engineEval: engineEval))

        // 2. LLM-generated main explanation
        if let llmText = try? await generateLLMExplanation(
            move: move,
            position: position,
            engineEval: engineEval,
            engineCandidates: engineCandidates
        ) {
            messages.append(CoachMessage(
                theme: .tactical,
                content: llmText,
                priority: .high,
                tone: .explanatory,
                category: .moveExplanation
            ))
        }

        return messages
    }

    // MARK: - Private Helpers

    private func verdictMessage(quality: MoveQuality, engineEval: EngineLine) -> CoachMessage {
        let content: String
        switch quality {
        case .brilliant:
            content = "Brilliant move! One of the best choices in this position."
        case .great:
            content = "A great move with clear advantages."
        case .good:
            content = "A solid move. Nothing wrong with it."
        case .inaccuracy:
            content = "This move is slightly imprecise. There were better options."
        case .mistake:
            content = "This move is a mistake. Let's look at what went wrong."
        case .blunder:
            content = "This move is a blunder that loses material or position."
        case .interesting:
            content = "An interesting move — unusual but potentially worth considering."
        case .dubious:
            content = "A dubious move. It's hard to find a good justification for it."
        case .best:
            content = "The absolute best move in this position — perfect!"
        }
        return CoachMessage(
            theme: .tactical,
            content: content,
            priority: .high,
            tone: .explanatory,
            category: .moveExplanation
        )
    }

    // MARK: - LLM Text Generation

    private func generateLLMExplanation(
        move: Move,
        position: Position,
        engineEval: EngineLine,
        engineCandidates: [EngineLine]
    ) async throws -> String {
        let pv = engineEval.pv
        let bestMoveStr = pv.count >= 4
            ? String(pv.prefix(4))
            : "\(move.from.file)\(move.from.rank)\(move.to.file)\(move.to.rank)"

        let alternatives: [(move: String, score: EngineScore)] = engineCandidates.prefix(3).compactMap { line in
            guard let uci = line.moves.first, uci.count >= 4 else { return nil }
            return (String(uci.prefix(4)), line.score)
        }

        let prompt = LLMCoachingPrompt(
            score: engineEval.score,
            bestMove: bestMoveStr,
            alternatives: alternatives,
            playerColor: position.turn
        )

        return try await llmService.generateCoachingText(from: prompt)
    }
}
