import Foundation

// MARK: - EngineLine

public struct EngineLine: Identifiable, Equatable {
    public let id = UUID()
    public let depth: Int
    public let score: EngineScore
    public let moves: [String]  // UCI move sequence, e.g. ["e2e4", "e7e5"]
    public let pv: String       // full PV string from UCI

    public init(depth: Int, score: EngineScore, moves: [String], pv: String) {
        self.depth = depth
        self.score = score
        self.moves = moves
        self.pv = pv
    }
}

// MARK: - EngineScore

public enum EngineScore: Equatable {
    case cp(Int)       // centipawns
    case mate(Int)     // moves to mate (positive = white winning)
    case upperBound(Int)
    case lowerBound(Int)

    public var displayString: String {
        switch self {
        case .cp(let cp):
            let sign = cp >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", Double(cp) / 100.0))"
        case .mate(let moves):
            return "M\(moves)"
        case .upperBound(let cp):
            return "≤\(String(format: "%.2f", Double(cp) / 100.0))"
        case .lowerBound(let cp):
            return "≥\(String(format: "%.2f", Double(cp) / 100.0))"
        }
    }

    public var centipawns: Double? {
        switch self {
        case .cp(let cp): return Double(cp)
        case .mate(let m): return m > 0 ? 10000 - Double(m) * 10 : -10000 - Double(m) * 10
        default: return nil
        }
    }
}
