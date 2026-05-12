import XCTest
@testable import ChessCoachEngine

final class EngineLineTests: XCTestCase {

    // MARK: - EngineScore displayString

    func testDisplayString_cpPositive() {
        XCTAssertEqual(EngineScore.cp(100).displayString, "+1.00")
    }

    func testDisplayString_cpNegative() {
        XCTAssertEqual(EngineScore.cp(-50).displayString, "-0.50")
    }

    func testDisplayString_cpZero() {
        XCTAssertEqual(EngineScore.cp(0).displayString, "+0.00")
    }

    func testDisplayString_matePositive() {
        XCTAssertEqual(EngineScore.mate(3).displayString, "M3")
    }

    func testDisplayString_mateNegative() {
        XCTAssertEqual(EngineScore.mate(-5).displayString, "M-5")
    }

    func testDisplayString_upperBound() {
        XCTAssertEqual(EngineScore.upperBound(120).displayString, "≤1.20")
    }

    func testDisplayString_lowerBound() {
        XCTAssertEqual(EngineScore.lowerBound(-80).displayString, "≥-0.80")
    }

    // MARK: - EngineScore centipawns

    func testCentipawns_cp() {
        XCTAssertEqual(EngineScore.cp(150).centipawns, 150.0)
    }

    func testCentipawns_matePositive() {
        XCTAssertEqual(EngineScore.mate(3).centipawns, 9970.0)
    }

    func testCentipawns_mateNegative() {
        XCTAssertEqual(EngineScore.mate(-5).centipawns, -9950.0)
    }

    func testCentipawns_upperBound_returnsNil() {
        XCTAssertNil(EngineScore.upperBound(50).centipawns)
    }

    func testCentipawns_lowerBound_returnsNil() {
        XCTAssertNil(EngineScore.lowerBound(-30).centipawns)
    }

    // MARK: - EngineLine

    func testEngineLine_init() {
        let line = EngineLine(
            depth: 20,
            score: .cp(35),
            moves: ["e2e4", "e7e5"],
            pv: "e2e4 e7e5"
        )
        XCTAssertEqual(line.depth, 20)
        XCTAssertEqual(line.score, .cp(35))
        XCTAssertEqual(line.moves, ["e2e4", "e7e5"])
        XCTAssertEqual(line.pv, "e2e4 e7e5")
    }

    func testEngineLine_equatable() {
        let a = EngineLine(depth: 20, score: .cp(35), moves: ["e2e4"], pv: "e2e4")
        let b = EngineLine(depth: 20, score: .cp(35), moves: ["e2e4"], pv: "e2e4")
        XCTAssertEqual(a, b)
    }
}
