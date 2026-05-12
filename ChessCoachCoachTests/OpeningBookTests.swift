import XCTest
@testable import ChessCoachCoach

final class OpeningBookTests: XCTestCase {

    var book: OpeningBook!

    override func setUp() {
        super.setUp()
        book = OpeningBook()
    }

    override func tearDown() {
        book = nil
        super.tearDown()
    }

    // MARK: - Load

    func testLoad_hasOpenings() {
        XCTAssertFalse(book.openings.isEmpty)
    }

    func testLoad_count() {
        // 8 built-in openings
        XCTAssertEqual(book.openings.count, 8)
    }

    // MARK: - Bookmarks

    func testBookmark_addsId() {
        let opening = book.openings[0]
        book.bookmark(opening)
        XCTAssertTrue(book.isBookmarked(opening))
    }

    func testBookmark_idempotent() {
        let opening = book.openings[0]
        book.bookmark(opening)
        book.bookmark(opening) // call twice
        let count = book.bookmarkedOpenings.filter { $0 == opening.id }.count
        XCTAssertEqual(count, 1)
    }

    func testUnbookmark_removesId() {
        let opening = book.openings[0]
        book.bookmark(opening)
        book.unbookmark(opening)
        XCTAssertFalse(book.isBookmarked(opening))
    }

    func testUnbookmark_notBookmarked_noCrash() {
        let opening = book.openings[0]
        book.unbookmark(opening) // not bookmarked — should not crash
        XCTAssertFalse(book.isBookmarked(opening))
    }

    // MARK: - Opening Data

    func testOpening_hasIdAndName() {
        for opening in book.openings {
            XCTAssertFalse(opening.id.isEmpty)
            XCTAssertFalse(opening.name.isEmpty)
        }
    }

    func testOpening_validFen() {
        for opening in book.openings {
            let pos = Position(fen: opening.fen)
            XCTAssertFalse(pos.isGameOver, "Opening '\(opening.name)' FEN should be valid")
        }
    }

    func testOpening_movesAreLegal() {
        var pos = Position()
        for opening in book.openings {
            for uci in opening.moves {
                let ok = pos.makeMove(uci: uci)
                XCTAssertTrue(ok, "Move \(uci) in opening '\(opening.name)' should be legal in FEN \(pos.fen)")
            }
            pos = Position() // reset
        }
    }
}
