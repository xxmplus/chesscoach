import XCTest
@testable import ChessCoachEngine

final class UCIParserTests: XCTestCase {

    // MARK: - parseInfoLine

    func testParseInfoLine_basic() {
        let line = "info depth 20 seldepth 25 multipv 1 score cp 42 pv e2e4 e7e5"
        let result = UCIParser.parseInfoLine(line)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.depth, 20)
        XCTAssertEqual(result?.score, .cp(42))
        XCTAssertEqual(result?.moves, ["e2e4", "e7e5"])
        XCTAssertEqual(result?.pv, "e2e4 e7e5")
    }

    func testParseInfoLine_mateScore() {
        let line = "info depth 30 score mate 3 pv g1f3"
        let result = UCIParser.parseInfoLine(line)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.score, .mate(3))
    }

    func testParseInfoLine_upperBound() {
        let line = "info depth 10 score upperbound cp 25 pv e2e4"
        let result = UCIParser.parseInfoLine(line)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.score, .upperBound(25))
    }

    func testParseInfoLine_lowerBound() {
        let line = "info depth 10 score lowerbound cp -10 pv e2e4"
        let result = UCIParser.parseInfoLine(line)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.score, .lowerBound(-10))
    }

    func testParseInfoLine_noPv_returnsNil() {
        let line = "info depth 20 seldepth 30 score cp 15"
        XCTAssertNil(UCIParser.parseInfoLine(line))
    }

    func testParseInfoLine_noScore_returnsNil() {
        let line = "info depth 20 seldepth 30 pv e2e4"
        XCTAssertNil(UCIParser.parseInfoLine(line))
    }

    func testParseInfoLine_notInfoLine_returnsNil() {
        XCTAssertNil(UCIParser.parseInfoLine("bestmove e2e4"))
        XCTAssertNil(UCIParser.parseInfoLine("readyok"))
        XCTAssertNil(UCIParser.parseInfoLine(""))
    }

    func testParseInfoLine_multipv() {
        let line = "info depth 15 multipv 2 score cp -30 pv d2d4 c7c5"
        let result = UCIParser.parseInfoLine(line)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.moves, ["d2d4", "c7c5"])
    }

    // MARK: - parseBestMove

    func testParseBestMove_basic() {
        let line = "bestmove e2e4"
        let (best, ponder) = UCIParser.parseBestMove(line)
        XCTAssertEqual(best, "e2e4")
        XCTAssertNil(ponder)
    }

    func testParseBestMove_withPonder() {
        let line = "bestmove e2e4 ponder d2d4"
        let (best, ponder) = UCIParser.parseBestMove(line)
        XCTAssertEqual(best, "e2e4")
        XCTAssertEqual(ponder, "d2d4")
    }

    func testParseBestMove_invalid_returnsEmpty() {
        for line in ["", "move e2e4", "info depth 10"] {
            let (best, ponder) = UCIParser.parseBestMove(line)
            XCTAssertEqual(best, "")
            XCTAssertNil(ponder)
        }
    }
}
