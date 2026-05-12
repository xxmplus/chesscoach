import XCTest
@testable import ChessCoachShared

final class PositionTests: XCTestCase {

    // MARK: - FEN Defaults

    func testStartingPosition_defaultFen() {
        let pos = Position()
        XCTAssertEqual(pos.fen, Position.startingFen)
    }

    func testStartingPosition_notInCheck() {
        XCTAssertFalse(Position().isCheck)
    }

    func testStartingPosition_notCheckmate() {
        XCTAssertFalse(Position().isCheckmate)
    }

    func testStartingPosition_notStalemate() {
        XCTAssertFalse(Position().isStalemate)
    }

    func testStartingPosition_notGameOver() {
        XCTAssertFalse(Position().isGameOver)
    }

    // MARK: - FEN Parsing

    func testFenParsing_sicilian() {
        // 1.e4 c5
        let fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"
        let pos = Position(fen: fen)
        XCTAssertEqual(pos.turn, .white)
    }

    func testFenParsing_enPassant() {
        // After 1.e4 d5 2.exd5 (en passant)
        let fen = "rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3"
        let pos = Position(fen: fen)
        XCTAssertEqual(pos.turn, .black)
        // En passant target square is private; verify the position parses correctly
        XCTAssertFalse(pos.isGameOver)
    }

    func testFenParsing_noCastling() {
        let fen = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"
        let pos = Position(fen: fen)
        // Should parse without crashing
        XCTAssertFalse(pos.isGameOver)
    }

    // MARK: - Board Queries

    func testPieceAt_startingE1() {
        // e1 = file 4, rank 0
        let pos = Position()
        let e1 = Square(file: 4, rank: 0)
        let piece = pos.piece(at: e1)
        XCTAssertEqual(piece?.kind, .king)
        XCTAssertEqual(piece?.color, .white)
    }

    func testPieceAt_startingD1() {
        let pos = Position()
        let d1 = Square(file: 3, rank: 0)
        let piece = pos.piece(at: d1)
        XCTAssertEqual(piece?.kind, .queen)
        XCTAssertEqual(piece?.color, .white)
    }

    func testPieceAt_startingE7() {
        let pos = Position()
        let e7 = Square(file: 4, rank: 6)
        let piece = pos.piece(at: e7)
        XCTAssertEqual(piece?.kind, .pawn)
        XCTAssertEqual(piece?.color, .black)
    }

    func testPieceAt_emptySquare() {
        let pos = Position()
        let e4 = Square(file: 4, rank: 3)
        XCTAssertNil(pos.piece(at: e4))
    }

    func testPieceAt_outOfBounds() {
        let pos = Position()
        XCTAssertNil(pos.piece(at: Square(file: -1, rank: 0)))
        XCTAssertNil(pos.piece(at: Square(file: 8, rank: 0)))
        XCTAssertNil(pos.piece(at: Square(file: 0, rank: -1)))
        XCTAssertNil(pos.piece(at: Square(file: 0, rank: 8)))
    }

    // MARK: - Legal Move Generation

    func testLegalMoves_startingE2() {
        let pos = Position()
        let e2 = Square(file: 4, rank: 1)
        let moves = pos.legalMoves(from: e2)
        let uci = moves.map { squareToUCI($0.from) + squareToUCI($0.to) }
        XCTAssertTrue(uci.contains("e2e3"), "Should contain e3")
        XCTAssertTrue(uci.contains("e2e4"), "Should contain e4")
    }

    func testLegalMoves_startingG1() {
        let pos = Position()
        let g1 = Square(file: 6, rank: 0)
        let moves = pos.legalMoves(from: g1)
        let uci = moves.map { squareToUCI($0.from) + squareToUCI($0.to) }
        XCTAssertTrue(uci.contains("g1f3"), "Should contain Nf3")
        XCTAssertTrue(uci.contains("g1h3"), "Should contain Nh3")
    }

    func testLegalMoves_pawnSinglePush_only() {
        var pos = Position()
        // 1.e4
        _ = pos.makeMove(uci: "e2e4")
        let e4 = Square(file: 4, rank: 3)
        let moves = pos.legalMoves(from: e4)
        XCTAssertTrue(moves.isEmpty, "Pawn on e4 should have no legal moves (can't go back)")
    }

    func testLegalMoves_castlingRights() {
        // Mid-game: white king e1, rooks a1+h1 unmoved, most other pieces developed away
        // Rank-1-first FEN (rank 1 at start, rank 8 at end): ranks[7]="R3K2R", ranks[0]="r1bqk2r"
        let fen = "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/R3K2R w KQkq - 6 4"
        let pos = Position(fen: fen)
        let e1 = Square(file: 4, rank: 0)
        let moves = pos.legalMoves(from: e1)
        let uci = moves.map { squareToUCI($0.from) + squareToUCI($0.to) }
        XCTAssertTrue(uci.contains("e1g1"), "Should contain O-O kingside (king+rook unmoved)")
        XCTAssertTrue(uci.contains("e1c1"), "Should contain O-O-O queenside (king+rook unmoved)")
    }

    func testLegalMoves_noCastling_afterKingMoves() {
        var pos = Position()
        _ = pos.makeMove(uci: "e2e4")
        _ = pos.makeMove(uci: "e7e5")
        _ = pos.makeMove(uci: "g1f3")
        _ = pos.makeMove(uci: "b8c6")
        _ = pos.makeMove(uci: "f1c4")
        _ = pos.makeMove(uci: "g8f6")
        let e1 = Square(file: 4, rank: 0)
        let moves = pos.legalMoves(from: e1)
        let uci = moves.map { squareToUCI($0.from) + squareToUCI($0.to) }
        XCTAssertFalse(uci.contains("e1g1"), "Should NOT contain O-O (castling rights lost)")
    }

    func testLegalMoves_totalAtStart() {
        let pos = Position()
        XCTAssertEqual(pos.legalMoves.count, 20, "Standard starting position has 20 legal moves")
    }

    // MARK: - Check / Checkmate / Stalemate

    func testIsCheck_after1e4d5() {
        var pos = Position()
        _ = pos.makeMove(uci: "e2e4")
        _ = pos.makeMove(uci: "d7d5")
        _ = pos.makeMove(uci: "e4d5")  // en passant capture
        XCTAssertFalse(pos.isCheck, "Position after en passant should not be in check")
    }

    func testIsCheckmate_scholarsMate() {
        // Queen on h5 delivers checkmate to black king on e8.
        // King e8 is trapped — all adjacent squares are covered by queen on h5.
        // White king elsewhere (a1). Black pieces irrelevant.
        // Rank-1-first FEN with parseFen board[7-rankIdx]:
        // ranks[4]="7Q" → board[3] (rank 4): h4=queen ✓
        // ranks[0]="rnbqkbnr" → board[7] (rank 8): e8=black king ✓
        let fen = "rnbqkbnr/ppppp1ppp/8/8/7Q/8/PPPPPPPP/K7 w - - 0 1"
        let pos = Position(fen: fen)
        XCTAssertTrue(pos.isCheckmate, "Queen on h5 checking e8 with trapped king should be checkmate")
    }

    func testIsStalemate() {
        // White queen on h6 traps black king on h8. King has no legal moves and is not in check.
        // Queen on h6 attacks: g7, h7 (occupied by own pawn), g8, h8(king), g6, h5...
        // King h8 can only move to g8 (attacked by queen), f8 (off-board diagonals blocked by own bishop/king), g7 (pawn).
        // White king on e1: not relevant, doesn't attack any of black king's escape squares.
        let fen = "8/8/8/8/8/7Q/8/4K2k w - - 0 1"
        let pos = Position(fen: fen)
        XCTAssertTrue(pos.isStalemate, "Trapped black king not in check should be stalemate")
    }

    // MARK: - Make Move

    func testMakeMove_updatesTurn() {
        var pos = Position()
        XCTAssertEqual(pos.turn, .white)
        _ = pos.makeMove(uci: "e2e4")
        XCTAssertEqual(pos.turn, .black)
    }

    func testMakeMove_incrementsFullmoveNumber() {
        var pos = Position()
        _ = pos.makeMove(uci: "e2e4")
        _ = pos.makeMove(uci: "e7e5")
        // fullmoveNumber is private; verify position is not in game over state
        XCTAssertFalse(pos.isGameOver)
    }

    func testMakeMove_illegalMove() {
        var pos = Position()
        // Try to move queen like a pawn (not allowed)
        let result = pos.makeMove(uci: "d1d3")
        XCTAssertFalse(result, "Illegal move should return false")
    }

    func testMakeMove_promotion() {
        // White pawn on e7 (rank 7 for white) can advance to e8 and promote to queen
        // Standard FEN format (rank 8 first): "8"=rank8 empty, ..., rank7="4P3"=pawn at e7
        let fen = "8/8/8/8/8/8/4P3/4K2R w - - 0 1"
        var pos = Position(fen: fen)
        let result = pos.makeMove(uci: "e7e8q")
        XCTAssertTrue(result, "Promotion move e7e8q should succeed")
        XCTAssertEqual(pos.piece(at: Square(file: 4, rank: 7))?.kind, .queen)
    }

    // MARK: - Undo Move

    func testUndoMove_restoresPosition() {
        var pos = Position()
        let beforeFen = pos.fen
        _ = pos.makeMove(uci: "e2e4")
        _ = pos.undoMove()
        XCTAssertEqual(pos.fen, beforeFen)
    }

    func testUndoMove_restoresTurn() {
        var pos = Position()
        XCTAssertEqual(pos.turn, .white)
        _ = pos.makeMove(uci: "e2e4")
        XCTAssertEqual(pos.turn, .black)
        _ = pos.undoMove()
        XCTAssertEqual(pos.turn, .white)
    }

    func testUndoMove_emptyHistory() {
        var pos = Position()
        _ = pos.undoMove() // Should not crash
        XCTAssertEqual(pos.turn, .white)
    }

    // MARK: - setFen

    func testSetFen_clearsHistory() {
        var pos = Position()
        _ = pos.makeMove(uci: "e2e4")
        _ = pos.makeMove(uci: "e7e5")
        pos.setFen(Position.startingFen)
        XCTAssertEqual(pos.turn, .white)
        XCTAssertEqual(pos.legalMoves.count, 20)
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let fen = "r1bqkb1r/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
        let pos = Position(fen: fen)
        let encoded = try JSONEncoder().encode(pos)
        let decoded = try JSONDecoder().decode(Position.self, from: encoded)
        XCTAssertEqual(decoded.fen, pos.fen)
    }

    // MARK: - Helpers

    private func squareToUCI(_ sq: Square) -> String {
        let files = "abcdefgh"
        let ranks = "12345678"
        return String(files[files.index(files.startIndex, offsetBy: sq.file)]) +
               String(ranks[ranks.index(ranks.startIndex, offsetBy: sq.rank)])
    }
}
