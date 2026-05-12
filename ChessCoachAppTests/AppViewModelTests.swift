import XCTest
import Combine
@testable import ChessCoachApp
@testable import ChessCoachShared
@testable import ChessCoachEngine
@testable import ChessCoachCoach

@MainActor
final class AppViewModelTests: XCTestCase {
    func testLearnViewModelFiltersLessonsAndPersistsProgress() {
        let model = LearnViewModel()
        XCTAssertFalse(model.lessons.isEmpty)

        let lesson = model.lessons[0]
        let initialProgress = model.progress(for: lesson)

        model.markStarted(lesson)
        XCTAssertEqual(model.progress(for: lesson).status, .inProgress)

        let targetStars = max(initialProgress.stars, 2)
        model.markCompleted(lesson, stars: targetStars)
        XCTAssertEqual(model.progress(for: lesson).status, .completed)
        XCTAssertEqual(model.progress(for: lesson).stars, targetStars)

        model.markCompleted(lesson, stars: 1)
        XCTAssertEqual(model.progress(for: lesson).stars, targetStars, "Completing with fewer stars must not downgrade progress")
        XCTAssertGreaterThan(model.completedCount, 0)
        XCTAssertGreaterThan(model.totalStars, 0)
        XCTAssertEqual(model.maxPossibleStars, model.lessons.count * 3)
        XCTAssertTrue(model.lessons(for: lesson.phase).allSatisfy { $0.phase == lesson.phase })
        XCTAssertEqual(model.lessons(for: nil).count, model.lessons.count)
    }

    func testPlayViewModelLoadsFenAndRecordsLegalUserAndEngineMoves() {
        let model = PlayViewModel()
        model.fenInput = "  rnbqkbnr/pppppppp/8/8/8/4P3/PPPP1PPP/RNBQKBNR b KQkq - 0 1  "

        model.loadFen()

        XCTAssertEqual(model.position.turn, .black)
        XCTAssertEqual(model.moveHistory, [])
        XCTAssertFalse(model.showCoach)

        model.makeEngineMove("e7e5")
        XCTAssertEqual(model.moveHistory, ["e7e5"])
        XCTAssertEqual(model.currentMoveIndex, 0)

        model.makeMove(Move(from: Square(file: 6, rank: 0), to: Square(file: 5, rank: 2)))
        XCTAssertEqual(model.moveHistory.last, "g1f3")
        XCTAssertEqual(model.currentMoveIndex, 1)

        model.dismissCoach()
        XCTAssertFalse(model.showCoach)
    }

    func testPlayViewModelAnalysisUsesEngineLinesAndBestMove() async {
        let model = PlayViewModel()
        let engine = FakeChessEngine(lines: [
            EngineLine(depth: 4, score: .cp(10), moves: ["e2e4"], pv: "e2e4"),
            EngineLine(depth: 8, score: .cp(20), moves: ["d2d4"], pv: "d2d4"),
            EngineLine(depth: 6, score: .cp(15), moves: ["c2c4"], pv: "c2c4")
        ])
        model.setEngine(engine)

        model.startAnalysis()
        await Task.yield()

        XCTAssertTrue(model.isAnalyzing)
        XCTAssertEqual(model.engineLines.map(\.depth), [8, 6, 4])
        XCTAssertEqual(model.bestMove, "d2d4")
        XCTAssertEqual(engine.requests.last?.depth, 20)
        XCTAssertNil(engine.requests.last?.timeout)

        model.stopAnalysis()
        XCTAssertFalse(model.isAnalyzing)
        XCTAssertEqual(engine.stopCount, 1)
    }

    func testPlayViewModelIgnoresUnavailableEngineForAnalysis() {
        let model = PlayViewModel()
        let engine = FakeChessEngine(lines: [])
        engine.isAvailable = false
        model.setEngine(engine)

        model.startAnalysis()

        XCTAssertFalse(model.isAnalyzing)
        XCTAssertTrue(engine.requests.isEmpty)
    }

    func testPuzzleViewModelLoadsPuzzleHintsAndWrongMoveFeedback() {
        let model = PuzzleViewModel()
        XCTAssertNotNil(model.currentPuzzle)
        XCTAssertFalse(model.isSolved)

        model.showHint()
        XCTAssertEqual(model.feedbackType, .hint)
        XCTAssertNotNil(model.currentHint)

        model.submitMove("a1a1")
        XCTAssertEqual(model.feedbackType, .wrong)
        XCTAssertEqual(model.feedbackMessage, "Not this move. Try again or use a hint.")
        XCTAssertEqual(model.attemptCount, 1)
    }

    func testPuzzleViewModelCompletesSingleMovePuzzle() {
        let model = PuzzleViewModel(puzzle: Puzzle(
            id: "unit-single",
            fen: Position.startingFen,
            solution: ["e2e4"],
            themes: ["opening"],
            difficulty: 1,
            rating: 900,
            hints: ["Play a central pawn"]
        ))

        model.submitMove("e2e4")

        XCTAssertTrue(model.isSolved)
        XCTAssertEqual(model.feedbackType, .correct)
        XCTAssertEqual(model.feedbackMessage, "Puzzle complete!")
    }

    func testProgressViewModelRecordsActivityAndReloadsTrackerState() {
        let model = ProgressViewModel()

        model.recordActivity()

        XCTAssertGreaterThanOrEqual(model.currentStreak, 0)
        XCTAssertGreaterThanOrEqual(model.bestStreak, model.currentStreak)
        XCTAssertGreaterThanOrEqual(model.estimatedRating, 100)
    }
}

private final class FakeChessEngine: ChessEngine {
    struct Request { let fen: String; let depth: Int?; let timeout: TimeInterval? }

    let displayName = "Fake Engine"
    var isAvailable = true
    var lastBestMove: String?
    var requests: [Request] = []
    var stopCount = 0
    private let lines: [EngineLine]

    init(lines: [EngineLine]) {
        self.lines = lines
        self.lastBestMove = lines.first?.moves.first
    }

    func initialize() async throws {}

    func startAnalysis(fen: String, depth: Int?, timeout: TimeInterval?) -> AnyPublisher<EngineLine, Never> {
        requests.append(Request(fen: fen, depth: depth, timeout: timeout))
        return Publishers.Sequence(sequence: lines).eraseToAnyPublisher()
    }

    func stopAnalysis() { stopCount += 1 }
    func shutdown() {}
}
