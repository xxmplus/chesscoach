import XCTest
@testable import ChessCoachShared

final class SquareTests: XCTestCase {

    // MARK: - Index

    func testIndex_center() {
        XCTAssertEqual(Square(file: 4, rank: 4).index, 36)
    }

    func testIndex_cornerA1() {
        XCTAssertEqual(Square(file: 0, rank: 0).index, 0)
    }

    func testIndex_cornerH8() {
        XCTAssertEqual(Square(file: 7, rank: 7).index, 63)
    }

    func testIndex_a8() {
        XCTAssertEqual(Square(file: 0, rank: 7).index, 56)
    }

    func testIndex_h1() {
        XCTAssertEqual(Square(file: 7, rank: 0).index, 7)
    }

    // MARK: - Description

    func testDescription_e4() {
        XCTAssertEqual(Square(description: "e4")?.description, "e4")
    }

    func testDescription_a1() {
        XCTAssertEqual(Square(description: "a1")?.description, "a1")
    }

    func testDescription_h8() {
        XCTAssertEqual(Square(description: "h8")?.description, "h8")
    }

    func testDescription_invalidLength() {
        XCTAssertNil(Square(description: "e"))
        XCTAssertNil(Square(description: "e44"))
        XCTAssertNil(Square(description: ""))
    }

    func testDescription_invalidFile() {
        XCTAssertNil(Square(description: "i1"))  // file > h
        XCTAssertNil(Square(description: "a9")) // rank > 8
    }

    // MARK: - All Squares

    func testAllSquares_count() {
        XCTAssertEqual(Square.allSquares.count, 64)
    }

    func testAllSquares_noDuplicates() {
        let squares = Square.allSquares
        let indices = squares.map { $0.index }
        XCTAssertEqual(indices.count, Set(indices).count, "allSquares should contain no duplicate indices")
    }

    // MARK: - Hashable

    func testHashable_equal() {
        let a = Square(file: 3, rank: 4)
        let b = Square(file: 3, rank: 4)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashable_notEqual() {
        let a = Square(file: 0, rank: 0)
        let b = Square(file: 1, rank: 0)
        XCTAssertNotEqual(a, b)
    }
}
