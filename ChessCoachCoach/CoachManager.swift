import Foundation
import ChessCoachShared
import ChessCoachEngine
import ChessCoachCoach

// MARK: - CoachManager

/// Manages the active coach engine — either the template-based CoachEngine
/// (instant, offline) or the LLM-powered LLMCoachEngine (richer explanations).
/// Device tier is detected at init time; the appropriate engine is configured.
@MainActor
public final class CoachManager: ObservableObject {

    // MARK: - Public State

    @Published public private(set) var isLLMAvailable: Bool = false
    @Published public private(set) var isLLMLoading: Bool = false
    @Published public private(set) var llmDownloadProgress: Double = 0.0
    @Published public var useLLM: Bool = true

    public var isReady: Bool {
        useLLM ? isLLMAvailable : true
    }

    // MARK: - Private State

    private let templateEngine: CoachEngine
    private var llmEngine: LLMCoachEngine?
    private let deviceTier: DeviceTier
    private let modelConfig: ModelConfig

    // MARK: - Init

    public init() {
        self.templateEngine = CoachEngine()
        self.deviceTier = DeviceCapabilityDetector.detectTier()
        self.modelConfig = deviceTier.recommendedModel
    }

    // MARK: - Lifecycle

    /// Initialize the coach engine. Loads the LLM if useLLM is enabled and the
    /// model file is present (or can be downloaded).
    public func initialize() async {
        guard useLLM else { return }

        isLLMLoading = true
        defer { isLLMLoading = false }

        let downloadService = ModelDownloadService()
        var modelPath = downloadService.modelPath(for: modelConfig)

        // If model not present, download it
        if !FileManager.default.fileExists(atPath: modelPath.path) {
            do {
                try await downloadService.downloadModel(
                    modelConfig,
                    progressHandler: { [weak self] progress in
                        Task { @MainActor in
                            self?.llmDownloadProgress = progress
                        }
                    }
                )
                modelPath = downloadService.modelPath(for: modelConfig)
            } catch {
                print("CoachManager: model download failed: \(error)")
                // Fall back to template engine
                return
            }
        }

        // Create adapter and load model
        let adapter = SwiftLlamaAdapter(modelPath: modelPath)

        do {
            try await adapter.loadModel()
            self.llmEngine = LLMCoachEngine(
                modelConfig: modelConfig,
                llmService: adapter,
                serverManager: nil  // macOS only
            )
            self.isLLMAvailable = true
        } catch {
            print("CoachManager: LLM load failed: \(error)")
        }
    }

    // MARK: - Generate

    /// Generate coaching messages for a move that was just played.
    public func generateMoveExplanation(
        move: Move,
        position: Position,
        engineEval: EngineLine,
        engineCandidates: [EngineLine],
        bestMove: Move?
    ) async -> [CoachMessage] {
        if useLLM, let llm = llmEngine, isLLMAvailable {
            return await llm.generateMoveExplanation(
                move: move,
                position: position,
                engineEval: engineEval,
                engineCandidates: engineCandidates,
                bestMove: bestMove
            )
        } else {
            return templateEngine.generateMoveExplanation(
                move: move,
                position: position,
                engineEval: engineEval,
                engineCandidates: engineCandidates,
                bestMove: bestMove
            )
        }
    }

    // MARK: - Model Info

    public var modelDisplayName: String {
        modelConfig.displayName
    }

    public var deviceTierDescription: String {
        switch deviceTier {
        case .iPhone13:   return "iPhone 13 (A15) — SmolLM2 recommended"
        case .iPhone14:   return "iPhone 14 (A15/A16) — SmolLM2 recommended"
        case .iPhone15ProOrLater: return "iPhone 15 Pro+ (A17+) — Qwen2.5-3B recommended"
        case .other:      return "iPad / Unknown — SmolLM2 recommended"
        }
    }
}
