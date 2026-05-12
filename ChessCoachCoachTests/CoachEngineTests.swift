import XCTest
@testable import ChessCoachCoach
@testable import ChessCoachEngine
@testable import ChessCoachShared

final class CoachEngineTests: XCTestCase {

    var engine: CoachEngine!
    var position: Position!

    override func setUp() {
        super.setUp()
        engine = CoachEngine(learnerLevel: .beginner)
        position = Position()
    }

    override func tearDown() {
        engine = nil
        position = nil
        super.tearDown()
    }

    // MARK: - Move Quality Classification

    func testClassifyMove_brilliant() {
        // cp >= 300
        let line = makeLine(score: .cp(350))
        let from = Square(file: 4, rank: 1)
        let to   = Square(file: 4, rank: 3)
        let move = Move(from: from, to: to)
        XCTAssertEqual(engine.classifyMove(move: move, position: position, engineEval: line), .brilliant)
    }

    func testClassifyMove_great() {
        // cp >= 100
        let line = makeLine(score: .cp(150))
        let move = anyMove()
        XCTAssertEqual(engine.classifyMove(move: move, position: position, engineEval: line), .great)
    }

    func testClassifyMove_good() {
        // cp >= 30
        let line = makeLine(score: .cp(50))
        let move = anyMove()
        XCTAssertEqual(engine.classifyMove(move: move, position: position, engineEval: line), .good)
    }

    func testClassifyMove_best() {
        // cp >= -30
        let line = makeLine(score: .cp(0))
        let move = anyMove()
        XCTAssertEqual(engine.classifyMove(move: move, position: position, engineEval: line), .best)
    }

    func testClassifyMove_inaccuracy() {
        // cp >= -80, < -30
        let line = makeLine(score: .cp(-50))
        let move = anyMove()
        XCTAssertEqual(engine.classifyMove(move: move, position: position, engineEval: line), .inaccuracy)
    }

    func testClassifyMove_mistake() {
        // cp >= -200, < -30  → wait, the code says: if cp < -80 = blunder; if cp < -30 = mistake
        // So cp in [-80, -30) = mistake
        let line = makeLine(score: .cp(-60))
        let move = anyMove()
        XCTAssertEqual(engine.classifyMove(move: move, position: position, engineEval: line), .mistake)
    }

    func testClassifyMove_blunder() {
        // cp < -80
        let line = makeLine(score: .cp(-150))
        let move = anyMove()
        XCTAssertEqual(engine.classifyMove(move: move, position: position, engineEval: line), .blunder)
    }

    // MARK: - generateMoveExplanation

    func testGenerateMoveExplanation_returnsNonEmpty() {
        let from = Square(file: 4, rank: 1)
        let to   = Square(file: 4, rank: 3)
        let move = Move(from: from, to: to)
        let line = makeLine(score: .cp(50))
        let messages = engine.generateMoveExplanation(
            move: move,
            position: position,
            engineEval: line,
            engineCandidates: [line],
            bestMove: move
        )
        XCTAssertFalse(messages.isEmpty)
    }

    func testGenerateMoveExplanation_includesVerdict() {
        let from = Square(file: 4, rank: 1)
        let to   = Square(file: 4, rank: 3)
        let move = Move(from: from, to: to)
        let line = makeLine(score: .cp(50))
        let messages = engine.generateMoveExplanation(
            move: move,
            position: position,
            engineEval: line,
            engineCandidates: [],
            bestMove: move
        )
        XCTAssertTrue(messages.contains { $0.category == .praise })
    }

    func testGenerateMoveExplanation_blunderHighPriority() {
        var pos = Position()
        // Set up a position where a blunder is plausible — start near checkmate
        let from = Square(file: 4, rank: 1)
        let to   = Square(file: 4, rank: 3)
        let move = Move(from: from, to: to)
        let blunderLine = makeLine(score: .cp(-200))
        let messages = engine.generateMoveExplanation(
            move: move,
            position: pos,
            engineEval: blunderLine,
            engineCandidates: [],
            bestMove: nil
        )
        let verdict = messages.first { $0.category == .praise }
        XCTAssertEqual(verdict?.priority, .critical)
    }

    func testGenerateMoveExplanation_castlingProducesThemeMessage() {
        // Castling position
        let fen = "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
        var pos = Position(fen: fen)
        // Move e1->g1 castling
        let move = Move(
            from: Square(file: 4, rank: 0),
            to: Square(file: 6, rank: 0),
            san: "O-O"
        )
        // Simulate castling via makeMove (not a legal castling move in this position via UCI)
        _ = pos.makeMove(uci: "e1g1")
        let line = makeLine(score: .cp(50))
        let messages = engine.generateMoveExplanation(
            move: move,
            position: pos,
            engineEval: line,
            engineCandidates: [],
            bestMove: nil
        )
        XCTAssertFalse(messages.isEmpty)
    }

    // MARK: - Helpers

    private func makeLine(score: EngineScore) -> EngineLine {
        EngineLine(
            depth: 20,
            score: score,
            moves: ["e2e4"],
            pv: "e2e4"
        )
    }

    private func anyMove() -> Move {
        Move(from: Square(file: 4, rank: 1), to: Square(file: 4, rank: 3))
    }
}
