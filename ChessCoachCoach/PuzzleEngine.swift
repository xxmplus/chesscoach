import Foundation
import Combine

// MARK: - Puzzle

public struct Puzzle: Identifiable, Codable {
    public let id: String
    public let fen: String
    public let solution: [String]  // Full correct UCI move sequence
    public let themes: [String]     // e.g. ["fork", "pin"]
    public let difficulty: Int       // internal 0-10 scale
    public let rating: Int          // Elo rating
    public let hints: [String]      // Progressive hint strings

    /// Number of moves in the solution
    public var moveCount: Int { solution.count }
}

public enum PuzzleResult: Equatable {
    case correct
    case wrong(move: String)
    case hintRequested
    case skipped
}

// MARK: - PuzzleEngine

/// Manages puzzle flow: loading, hint system, solution checking, rating.
public final class PuzzleEngine: ObservableObject {
    @Published public private(set) var currentPuzzle: Puzzle?
    @Published public private(set) var attemptIndex: Int = 0   // which move in solution we are at
    @Published public private(set) var hintsUsed: Int = 0
    @Published public private(set) var isSolved: Bool = false
    @Published public private(set) var wrongMove: String?

    private var cancellable: AnyCancellable?

    public init() {}

    public func load(_ puzzle: Puzzle) {
        currentPuzzle = puzzle
        attemptIndex = 0
        hintsUsed = 0
        isSolved = false
        wrongMove = nil
    }

    public func submitMove(_ uci: String) -> PuzzleResult {
        guard let puzzle = currentPuzzle else { return .skipped }
        let expected = puzzle.solution[safe: attemptIndex]
        if uci == expected {
            attemptIndex += 1
            wrongMove = nil
            if attemptIndex >= puzzle.solution.count {
                isSolved = true
                return .correct
            }
            return .correct
        } else {
            wrongMove = uci
            return .wrong(move: uci)
        }
    }

    public func requestHint() -> String? {
        guard let puzzle = currentPuzzle,
              hintsUsed < puzzle.hints.count else { return nil }
        let hint = puzzle.hints[hintsUsed]
        hintsUsed += 1
        return hint
    }

    public func reset() {
        guard let puzzle = currentPuzzle else { return }
        load(puzzle)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
