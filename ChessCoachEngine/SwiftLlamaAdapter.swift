import Foundation
import SwiftLlama

// MARK: - SwiftLlamaAdapter

/// Adapter bridging LLMService to pgorzelany/swift-llama-cpp.
/// Uses LlamaService.actor with Metal-accelerated GGUF inference.
public final class SwiftLlamaAdapter: LLMService {

    private var llamaService: LlamaService?
    private let modelPath: URL

    public var isReady: Bool {
        llamaService != nil
    }

    public init(modelPath: URL) {
        self.modelPath = modelPath
    }

    public func loadModel() async throws {
        let config = LlamaConfig(
            batchSize: 512,
            maxTokenCount: 512,
            useGPU: true
        )
        llamaService = LlamaService(modelUrl: modelPath, config: config)
    }

    public func unloadModel() async {
        llamaService = nil
    }

    public func generateCoachingText(
        from prompt: LLMCoachingPrompt
    ) async throws -> String {
        guard let service = llamaService else {
            throw LLMError.modelNotLoaded
        }

        let messages: [LlamaChatMessage] = [
            LlamaChatMessage(role: .system, content: systemPrompt()),
            LlamaChatMessage(role: .user, content: prompt.promptString)
        ]

        let samplingConfig = LlamaSamplingConfig(
            temperature: 0.6,
            seed: 42,
            topP: 0.95,
            topK: nil,
            minKeep: 1,
            grammarConfig: nil,
            repetitionPenaltyConfig: nil
        )

        return try await service.respond(to: messages, samplingConfig: samplingConfig)
    }

    private func systemPrompt() -> String {
        """
        You are an expert chess coach helping a beginner improve to intermediate level.
        Keep explanations concise and encouraging. Focus on the single most important insight.
        Use plain language. Write exactly 2 sentences.
        """
    }
}
