import SwiftUI
import Combine
import ChessCoachShared
import ChessCoachEngine
import ChessCoachCoach

@MainActor
final class PuzzleViewModel: ObservableObject {
    @Published var currentPuzzle: Puzzle?
    @Published var position: Position = Position()
    @Published var feedbackMessage: String?
    @Published var feedbackType: FeedbackType?
    @Published var hintsUsed: Int = 0
    @Published var currentHint: String?
    @Published var isSolved: Bool = false
    @Published var attemptCount: Int = 0
    @Published var puzzlePool: [Puzzle] = []
    @Published var engineLines: [EngineLine] = []
    @Published var isAnalyzing: Bool = false

    enum FeedbackType { case correct, wrong, hint }

    private let engine = PuzzleEngine()
    private let loader = ContentLoader.shared
    private var cancellables = Set<AnyCancellable>()

    /// The color the human player plays as in this puzzle. Set once at load and never changes,
    /// even after opponent moves are applied to the board.
    private var userColor: PieceColor = .white

    /// The color the human player plays as. Always the original side-to-move in the FEN.
    var playerColor: PieceColor {
        userColor
    }

    init() {
        loadNextPuzzle()
    }

    init(puzzle: Puzzle) {
        load(puzzle)
    }

    func loadNextPuzzle() {
        let all = loader.loadPuzzles()
        if let puzzle = all.randomElement() {
            load(puzzle)
        }
    }

    private func load(_ puzzle: Puzzle) {
        currentPuzzle = puzzle
        position = Position(fen: puzzle.fen)
        userColor = position.turn
        engine.load(puzzle)
        feedbackMessage = nil
        feedbackType = nil
        hintsUsed = 0
        currentHint = nil
        isSolved = false
        attemptCount = 0
        engineLines = []
    }

    func submitMove(_ uci: String) {
        guard currentPuzzle != nil else { return }
        let result = engine.submitMove(uci)
        switch result {
        case .correct:
            isSolved = engine.isSolved
            if isSolved {
                feedbackMessage = "Puzzle complete!"
                feedbackType = .correct
            } else {
                // engine.attemptIndex is now 1 past the move just confirmed.
                // The opponent's move is at solution[engine.attemptIndex].
                if engine.attemptIndex < currentPuzzle?.solution.count ?? 0,
                   let opponentMove = currentPuzzle?.solution[engine.attemptIndex] {
                    applyOpponentMove(opponentMove)
                }
                feedbackMessage = "Good move. Find the next move."
                feedbackType = .correct
            }
        case .wrong(let move):
            feedbackMessage = "Not this move. Try again or use a hint."
            feedbackType = .wrong
            attemptCount += 1
            revertLastMove()
            showEngineLine(for: move)
        case .hintRequested:
            break
        case .skipped:
            break
        }
    }

    func showHint() {
        currentHint = engine.requestHint()
        feedbackType = .hint
    }

    func skipPuzzle() {
        ProgressTracker().puzzleFailed(rating: currentPuzzle?.rating ?? 1000, themes: currentPuzzle?.themes ?? [])
        loadNextPuzzle()
    }

    func revertLastMove() {
        guard let puzzle = currentPuzzle else { return }
        position = Position(fen: puzzle.fen)
        engine.reset()
    }

    private func applyOpponentMove(_ uci: String) {
        var newPos = position
        if newPos.makeMove(uci: uci) {
            position = newPos
        }
    }

    private func showEngineLine(for move: String) {
        // Show the engine evaluation of the wrong move
        // (In a full impl, this would query the engine)
    }
}
