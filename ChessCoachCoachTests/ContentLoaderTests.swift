import XCTest
@testable import ChessCoachCoach
@testable import ChessCoachShared

final class ContentLoaderTests: XCTestCase {

    var loader: ContentLoader!

    override func setUp() {
        super.setUp()
        loader = ContentLoader.shared
    }

    // MARK: - Lessons

    func testLoadLessons_count() {
        let lessons = loader.loadLessons()
        XCTAssertEqual(lessons.count, 9)
    }

    func testLessonPhases_allPresent() {
        let lessons = loader.loadLessons()
        let phases = Set(lessons.map { $0.phase })
        XCTAssertTrue(phases.contains(.opening))
        XCTAssertTrue(phases.contains(.middlegame))
        XCTAssertTrue(phases.contains(.endgame))
    }

    func testLessonsByPhase_opening() {
        let lessons = loader.loadLessons()
        let openingCount = lessons.filter { $0.phase == .opening }.count
        XCTAssertEqual(openingCount, 3)
    }

    func testLesson_hasPositions() {
        let lessons = loader.loadLessons()
        for lesson in lessons {
            XCTAssertFalse(lesson.positions.isEmpty, "Lesson '\(lesson.id)' should have at least one position")
        }
    }

    func testLessonPosition_validFen() {
        let lessons = loader.loadLessons()
        for lesson in lessons {
            for position in lesson.positions {
                let pos = Position(fen: position.fen)
                // Should not throw or be obviously invalid
                XCTAssertFalse(pos.isGameOver || pos.legalMoves.isEmpty,
                    "Lesson '\(lesson.id)' position FEN should be valid")
            }
        }
    }

    func testLesson_hasTitleAndBody() {
        let lessons = loader.loadLessons()
        for lesson in lessons {
            XCTAssertFalse(lesson.title.isEmpty)
            XCTAssertFalse(lesson.body.isEmpty)
        }
    }

    // MARK: - Puzzles

    func testLoadPuzzles_count() {
        let puzzles = loader.loadPuzzles()
        XCTAssertEqual(puzzles.count, 8)
    }

    func testPuzzleSolution_nonEmpty() {
        let puzzles = loader.loadPuzzles()
        for puzzle in puzzles {
            XCTAssertFalse(puzzle.solution.isEmpty, "Puzzle '\(puzzle.id)' should have a solution")
        }
    }

    func testPuzzleHints_nonEmpty() {
        let puzzles = loader.loadPuzzles()
        for puzzle in puzzles {
            XCTAssertFalse(puzzle.hints.isEmpty, "Puzzle '\(puzzle.id)' should have at least one hint")
        }
    }

    func testPuzzleRatingRange() {
        let puzzles = loader.loadPuzzles()
        let ratings = puzzles.map { $0.rating }
        let min = ratings.min()!
        let max = ratings.max()!
        XCTAssertGreaterThanOrEqual(min, 600)
        XCTAssertLessThanOrEqual(max, 1700)
    }

    func testPuzzleRatingGroupings() {
        let puzzles = loader.loadPuzzles()
        let easy = puzzles.filter { $0.rating < 900 }
        let medium = puzzles.filter { $0.rating >= 900 && $0.rating < 1200 }
        let hard = puzzles.filter { $0.rating >= 1200 }
        XCTAssertFalse(easy.isEmpty, "Should have easy puzzles (rating < 900)")
        XCTAssertFalse(medium.isEmpty, "Should have medium puzzles (900-1200)")
        XCTAssertFalse(hard.isEmpty, "Should have hard puzzles (1200+)")
    }

    func testPuzzleMultiMove_p006() {
        let puzzles = loader.loadPuzzles()
        guard let p006 = puzzles.first(where: { $0.id == "p-006" }) else {
            XCTFail("p-006 should exist")
            return
        }
        XCTAssertEqual(p006.solution.count, 3, "p-006 should be a 3-move puzzle")
        XCTAssertEqual(p006.rating, 1300)
    }

    // MARK: - Puzzle Filtering

    func testPuzzlesForRating_returnsPuzzles() {
        let puzzles = loader.puzzles(for: 800, limit: 5)
        XCTAssertLessThanOrEqual(puzzles.count, 5)
    }

    func testNextPuzzle_returnsOnePuzzle() {
        let puzzle = loader.nextPuzzle(for: 1000)
        XCTAssertNotNil(puzzle)
    }
}
