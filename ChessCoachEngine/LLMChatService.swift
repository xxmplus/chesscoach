import Foundation

// MARK: - LLMChatService

/// Connects to a local llama-server instance and generates text via OpenAI-compatible API.
/// Used on macOS where llama-server can run as a subprocess.
/// On iOS, use SwiftLlamaAdapter instead.
public actor LLMChatService {

    private let baseURL: URL
    private var loadedModelPath: String?
    private let session: URLSession
    private let decoder = JSONDecoder()

    public var isReady: Bool { loadedModelPath != nil }

    public init(port: Int = 8080) {
        self.baseURL = URL(string: "http://localhost:\(port)")!
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Model Loading

    public func loadModel(at path: String) async throws {
        let models = try await fetchModels()
        if models.isEmpty {
            throw LLMError.modelLoadFailed("No models loaded on server")
        }
        loadedModelPath = path
    }

    public func unloadModel() {
        loadedModelPath = nil
    }

    // MARK: - Generation

    public func generateCoachingText(from prompt: LLMCoachingPrompt) async throws -> String {
        guard loadedModelPath != nil else {
            throw LLMError.modelNotLoaded
        }
        return try await generate(
            systemPrompt: "You are a friendly chess coach for beginners.",
            userPrompt: prompt.promptString
        )
    }

    public func streamCoachingText(from prompt: LLMCoachingPrompt) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Streaming not yet implemented for HTTP backend
                do {
                    let result = try await self.generateCoachingText(from: prompt)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generate(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int = 150,
        temperature: Double = 0.7
    ) async throws -> String {
        let request = ChatCompletionRequest(
            model: "local",
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: userPrompt)
            ],
            maxTokens: maxTokens,
            temperature: temperature
        )

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.generationFailed("Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            throw LLMError.generationFailed("Server returned \(httpResponse.statusCode)")
        }

        let reply = try decoder.decode(ChatCompletionResponse.self, from: data)
        guard let content = reply.choices.first?.message.content else {
            throw LLMError.generationFailed("No content in response")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func fetchModels() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/models"))
        request.timeoutInterval = 5
        let (data, _) = try await session.data(for: request)
        let response = try decoder.decode(ModelsResponse.self, from: data)
        return response.data.map { $0.id }
    }
}

// MARK: - OpenAI-Compatible API Types

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model, messages, maxTokens, temperature
    }
}

private struct Message: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct ModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }
    let data: [Model]
}
