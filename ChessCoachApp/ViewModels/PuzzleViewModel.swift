import SwiftUI
import Combine

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

    init() {
        loadNextPuzzle()
    }

    func loadNextPuzzle() {
        let all = loader.loadPuzzles()
        currentPuzzle = all.randomElement()
        if let p = currentPuzzle {
            position = Position(fen: p.fen)
        }
        feedbackMessage = nil
        feedbackType = nil
        hintsUsed = 0
        currentHint = nil
        isSolved = false
        attemptCount = 0
        engineLines = []
    }

    func submitMove(_ uci: String) {
        guard let puzzle = currentPuzzle else { return }
        let result = engine.submitMove(uci)
        switch result {
        case .correct:
            if isSolved {
                feedbackMessage = "Puzzle complete!"
                feedbackType = .correct
            } else {
                // Need more moves
                break
            }
        case .wrong(let move):
            feedbackMessage = "Not this move. Try again or use a hint."
            feedbackType = .wrong
            attemptCount += 1
            // Show engine-preferred line
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

    private func showEngineLine(for move: String) {
        // Show the engine evaluation of the wrong move
        // (In a full impl, this would query the engine)
    }
}
