import Foundation

// MARK: - LocalInferenceConfig

/// Device-tier detection and model selection for on-device LLM inference.
/// Uses pgorzelany/swift-llama-cpp for Metal-accelerated GGUF inference on iOS 17+.
public enum DeviceTier {
    /// iPhone 13 series — A15 Bionic
    case iPhone13
    /// iPhone 14 series — A15/A16
    case iPhone14
    /// iPhone 15 Pro and newer — A17+ with Neural Engine
    case iPhone15ProOrLater
    /// iPad or unknown
    case other

    public var recommendedModel: ModelConfig {
        switch self {
        case .iPhone13:
            return .smolLM2_1_7B
        case .iPhone14:
            return .smolLM2_1_7B
        case .iPhone15ProOrLater:
            return .qwen2_5_3B
        case .other:
            return .smolLM2_1_7B
        }
    }
}

public struct ModelConfig: Equatable, Sendable {
    public let repoId: String
    public let fileName: String
    public let displayName: String
    public let bundleSizeMB: Int
    /// Rough tokens/second estimate on iPhone 15 Pro (Metal, Q4_K_M)
    public let estimatedTokensPerSecond: Int
    /// Chat template name as understood by llama.cpp built-ins
    public let chatTemplate: String

    public var downloadURL: String {
        "https://huggingface.co/\(repoId)/resolve/main/\(fileName)"
    }

    public var huggingFaceRepo: String {
        "https://huggingface.co/\(repoId)/tree/main"
    }

    /// Qwen2.5-3B Instruct — best quality for chess coaching explanations.
    /// ~1.9GB (Q4_K_M), ~20 tok/s on iPhone 15 Pro.
    public static let qwen2_5_3B = ModelConfig(
        repoId: "Qwen/Qwen2.5-3B-Instruct-GGUF",
        fileName: "qwen2.5-3b-instruct-q4_k_m.gguf",
        displayName: "Qwen2.5-3B Instruct",
        bundleSizeMB: 2060,
        estimatedTokensPerSecond: 20,
        chatTemplate: "chatml"
    )

    /// SmolLM2-1.7B — smaller, faster, decent quality.
    /// ~950MB (Q4_K_M), ~25 tok/s on iPhone 15 Pro.
    public static let smolLM2_1_7B = ModelConfig(
        repoId: "swissbase/SmolLM2-1.7B-Instruct-GGUF",
        fileName: "smollm2-1.7b-instruct-q4_k_m.gguf",
        displayName: "SmolLM2-1.7B Instruct",
        bundleSizeMB: 950,
        estimatedTokensPerSecond: 25,
        chatTemplate: "chatml"
    )
}

/// Detects the current device tier from hardware identifier.
public struct DeviceCapabilityDetector: Sendable {
    public static func detectTier() -> DeviceTier {
        #if targetEnvironment(simulator)
        return .iPhone15ProOrLater // simulators are fast; use best model
        #else
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let identifier = String(cString: machine)

        if identifier.hasPrefix("iPhone16") {
            return .iPhone15ProOrLater
        }
        if identifier.hasPrefix("iPhone15") && (identifier.contains("Pro") || identifier.contains("Ultra")) {
            return .iPhone15ProOrLater
        }
        if identifier.hasPrefix("iPhone15") {
            return .iPhone14
        }
        if identifier.hasPrefix("iPhone14") {
            return .iPhone14
        }
        if identifier.hasPrefix("iPhone13") {
            return .iPhone13
        }
        return .other
        #endif
    }
}
