import XCTest
@testable import ChessCoachShared

final class MoveTests: XCTestCase {

    func testId_basic() {
        let from = Square(file: 4, rank: 1)  // e2
        let to   = Square(file: 4, rank: 3)  // e4
        let move = Move(from: from, to: to, promotion: nil, san: "e4", enPassant: false)
        XCTAssertEqual(move.id, "e2e4")
    }

    func testId_withPromotion() {
        let from = Square(file: 4, rank: 6)  // e7
        let to   = Square(file: 4, rank: 7)  // e8
        let move = Move(from: from, to: to, promotion: .queen, san: "e8=Q", enPassant: false)
        XCTAssertEqual(move.id, "e7e8Q")
    }

    func testId_enPassant() {
        let from = Square(file: 3, rank: 3)  // d4
        let to   = Square(file: 2, rank: 2)  // c3
        let move = Move(from: from, to: to, promotion: nil, san: "dxc3", enPassant: true)
        XCTAssertEqual(move.id, "d4c3")
        XCTAssertTrue(move.enPassant)
    }

    func testEnPassant_defaultFalse() {
        let from = Square(file: 4, rank: 1)
        let to   = Square(file: 4, rank: 3)
        let move = Move(from: from, to: to)
        XCTAssertFalse(move.enPassant)
    }

    func testPromotion_defaultNil() {
        let from = Square(file: 4, rank: 1)
        let to   = Square(file: 4, rank: 3)
        let move = Move(from: from, to: to)
        XCTAssertNil(move.promotion)
    }

    func testPromotion_knight() {
        let from = Square(file: 4, rank: 6)
        let to   = Square(file: 4, rank: 7)
        let move = Move(from: from, to: to, promotion: .knight)
        XCTAssertEqual(move.promotion, .knight)
    }

    func testSan_defaultEmpty() {
        let from = Square(file: 0, rank: 0)
        let to   = Square(file: 1, rank: 0)
        let move = Move(from: from, to: to)
        XCTAssertEqual(move.san, "")
    }

    // MARK: - Hashable

    func testHashable_equal() {
        let from = Square(file: 0, rank: 0)
        let to   = Square(file: 7, rank: 7)
        let a = Move(from: from, to: to, promotion: .queen, san: "a1h8Q")
        let b = Move(from: from, to: to, promotion: .queen, san: "a1h8Q")
        XCTAssertEqual(a, b)
    }

    func testHashable_notEqual_differentTo() {
        let from = Square(file: 0, rank: 0)
        let a = Move(from: from, to: Square(file: 7, rank: 7))
        let b = Move(from: from, to: Square(file: 6, rank: 7))
        XCTAssertNotEqual(a, b)
    }
}
