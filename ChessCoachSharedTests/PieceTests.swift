import XCTest
@testable import ChessCoachShared

final class PieceTests: XCTestCase {

    // MARK: - Symbol

    func testSymbol_whiteKing()   { XCTAssertEqual(Piece(kind: .king,   color: .white).symbol, "K") }
    func testSymbol_whiteQueen()  { XCTAssertEqual(Piece(kind: .queen,  color: .white).symbol, "Q") }
    func testSymbol_whiteRook()   { XCTAssertEqual(Piece(kind: .rook,   color: .white).symbol, "R") }
    func testSymbol_whiteBishop() { XCTAssertEqual(Piece(kind: .bishop, color: .white).symbol, "B") }
    func testSymbol_whiteKnight() { XCTAssertEqual(Piece(kind: .knight, color: .white).symbol, "N") }
    func testSymbol_whitePawn()   { XCTAssertEqual(Piece(kind: .pawn,   color: .white).symbol, "P") }

    func testSymbol_blackKing()   { XCTAssertEqual(Piece(kind: .king,   color: .black).symbol, "k") }
    func testSymbol_blackQueen()  { XCTAssertEqual(Piece(kind: .queen,  color: .black).symbol, "q") }
    func testSymbol_blackRook()   { XCTAssertEqual(Piece(kind: .rook,   color: .black).symbol, "r") }
    func testSymbol_blackBishop() { XCTAssertEqual(Piece(kind: .bishop, color: .black).symbol, "b") }
    func testSymbol_blackKnight() { XCTAssertEqual(Piece(kind: .knight, color: .black).symbol, "n") }
    func testSymbol_blackPawn()   { XCTAssertEqual(Piece(kind: .pawn,   color: .black).symbol, "p") }

    // MARK: - Character (Unicode)

    func testCharacter_whiteKing()   { XCTAssertEqual(Piece(kind: .king,   color: .white).character, "♔") }
    func testCharacter_whiteQueen()  { XCTAssertEqual(Piece(kind: .queen,  color: .white).character, "♕") }
    func testCharacter_whiteRook()   { XCTAssertEqual(Piece(kind: .rook,   color: .white).character, "♖") }
    func testCharacter_whiteBishop() { XCTAssertEqual(Piece(kind: .bishop, color: .white).character, "♗") }
    func testCharacter_whiteKnight() { XCTAssertEqual(Piece(kind: .knight, color: .white).character, "♘") }
    func testCharacter_whitePawn()   { XCTAssertEqual(Piece(kind: .pawn,   color: .white).character, "♙") }

    func testCharacter_blackKing()   { XCTAssertEqual(Piece(kind: .king,   color: .black).character, "♚") }
    func testCharacter_blackQueen()  { XCTAssertEqual(Piece(kind: .queen,  color: .black).character, "♛") }
    func testCharacter_blackRook()   { XCTAssertEqual(Piece(kind: .rook,   color: .black).character, "♜") }
    func testCharacter_blackBishop() { XCTAssertEqual(Piece(kind: .bishop, color: .black).character, "♝") }
    func testCharacter_blackKnight() { XCTAssertEqual(Piece(kind: .knight, color: .black).character, "♞") }
    func testCharacter_blackPawn()   { XCTAssertEqual(Piece(kind: .pawn,   color: .black).character, "♟") }

    // MARK: - ID

    func testId_whiteKing()  { XCTAssertEqual(Piece(kind: .king,   color: .white).id, "whiteK") }
    func testId_blackQueen() { XCTAssertEqual(Piece(kind: .queen,  color: .black).id, "blackQ") }

    // MARK: - PieceKind CaseIterable

    func testPieceKindAll_count() {
        XCTAssertEqual(PieceKind.allCases.count, 6)
    }
}
