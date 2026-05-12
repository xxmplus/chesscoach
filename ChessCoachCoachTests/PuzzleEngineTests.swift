import XCTest
@testable import ChessCoachCoach

final class PuzzleEngineTests: XCTestCase {

    var sut: PuzzleEngine!

    override func setUp() {
        super.setUp()
        sut = PuzzleEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Load

    func testLoad_resetsState() {
        let puzzle = makePuzzle(id: "p-001", solution: ["e2e4"])
        sut.load(puzzle)
        XCTAssertEqual(sut.currentPuzzle?.id, "p-001")
        XCTAssertEqual(sut.attemptIndex, 0)
        XCTAssertEqual(sut.hintsUsed, 0)
        XCTAssertFalse(sut.isSolved)
        XCTAssertNil(sut.wrongMove)
    }

    // MARK: - Submit Move

    func testSubmitMove_correctSingleMove() {
        sut.load(makePuzzle(solution: ["e2e4"]))
        let result = sut.submitMove("e2e4")
        XCTAssertEqual(result, .correct)
        XCTAssertTrue(sut.isSolved)
    }

    func testSubmitMove_wrongMove() {
        sut.load(makePuzzle(solution: ["e2e4"]))
        let result = sut.submitMove("d2d4")
        if case .wrong(let move) = result {
            XCTAssertEqual(move, "d2d4")
        } else {
            XCTFail("Expected .wrong, got \(result)")
        }
    }

    func testSubmitMove_partialCorrect() {
        sut.load(makePuzzle(solution: ["e2e4", "e7e5", "f1c4"]))
        let r1 = sut.submitMove("e2e4")
        XCTAssertEqual(r1, .correct)
        XCTAssertFalse(sut.isSolved)
        XCTAssertEqual(sut.attemptIndex, 1)
        let r2 = sut.submitMove("e7e5")
        XCTAssertEqual(r2, .correct)
        XCTAssertFalse(sut.isSolved)
        let r3 = sut.submitMove("f1c4")
        XCTAssertEqual(r3, .correct)
        XCTAssertTrue(sut.isSolved)
    }

    func testSubmitMove_completeSolution_returnsCorrect() {
        sut.load(makePuzzle(solution: ["e2e4", "e7e5"]))
        _ = sut.submitMove("e2e4")
        let result = sut.submitMove("e7e5")
        XCTAssertEqual(result, .correct)
        XCTAssertTrue(sut.isSolved)
    }

    func testSubmitMove_wrongAfterPartial_correctIndex() {
        sut.load(makePuzzle(solution: ["e2e4", "e7e5"]))
        _ = sut.submitMove("e2e4")
        _ = sut.submitMove("d7d5") // wrong
        XCTAssertEqual(sut.attemptIndex, 1, "attemptIndex should not advance on wrong move")
    }

    func testSubmitMove_noPuzzle_returnsSkipped() {
        let result = sut.submitMove("e2e4")
        if case .skipped = result {
            // pass
        } else {
            XCTFail("Expected .skipped")
        }
    }

    // MARK: - Hints

    func testRequestHint_returnsFirstHint() {
        let hints = ["Look at the center", "Control e5"]
        sut.load(makePuzzle(solution: ["e2e4"], hints: hints))
        let hint = sut.requestHint()
        XCTAssertEqual(hint, "Look at the center")
        XCTAssertEqual(sut.hintsUsed, 1)
    }

    func testRequestHint_returnsProgressiveHints() {
        let hints = ["Hint 1", "Hint 2", "Hint 3"]
        sut.load(makePuzzle(solution: ["e2e4"], hints: hints))
        XCTAssertEqual(sut.requestHint(), "Hint 1")
        XCTAssertEqual(sut.requestHint(), "Hint 2")
        XCTAssertEqual(sut.requestHint(), "Hint 3")
    }

    func testRequestHint_exhausted_returnsNil() {
        sut.load(makePuzzle(solution: ["e2e4"], hints: ["Only one hint"]))
        _ = sut.requestHint()
        XCTAssertNil(sut.requestHint())
        XCTAssertNil(sut.requestHint()) // still nil on repeated calls
    }

    func testRequestHint_noPuzzle_returnsNil() {
        XCTAssertNil(sut.requestHint())
    }

    // MARK: - Reset

    func testReset_restartsPuzzle() {
        sut.load(makePuzzle(solution: ["e2e4", "e7e5"]))
        _ = sut.submitMove("e2e4")
        sut.reset()
        XCTAssertEqual(sut.attemptIndex, 0)
        XCTAssertFalse(sut.isSolved)
        XCTAssertEqual(sut.hintsUsed, 0)
    }

    // MARK: - Helpers

    private func makePuzzle(
        id: String = "p-test",
        solution: [String],
        hints: [String] = ["Hint"]
    ) -> Puzzle {
        Puzzle(
            id: id,
            fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            solution: solution,
            themes: ["test"],
            difficulty: 1,
            rating: 1000,
            hints: hints
        )
    }
}
