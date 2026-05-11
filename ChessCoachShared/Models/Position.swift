import Foundation
import ChessKit

// MARK: - Position

/// A chess position backed by ChessKit for move generation/validation
/// and FEN serialization.
public struct Position: Codable, Equatable {
    private var game: Chess.Game

    public var fen: String { game.fen }
    public var turn: PieceColor { game.turn == .white ? .white : .black }
    public var isCheck: Bool { game.isCheck }
    public var isCheckmate: Bool { game.isCheckmate }
    public var isStalemate: Bool { game.isStalemate }
    public var isGameOver: Bool { game.isGameOver }

    public init(fen: String = Chess.Game.initialPosition.fen) {
        self.game = Chess.Game(fen: fen) ?? Chess.Game()
    }

    public init(game: Chess.Game) {
        self.game = game
    }

    /// Make a move in UCI format (e.g. "e2e4" or "e7e8q" for promotion)
    public mutating func makeMove(uci: String) -> Bool {
        let adjusted = uci.count == 4 ? uci + "q" : uci
        return game.makeMove(moving: adjusted)
    }

    /// Make a move from a Move struct
    public mutating func makeMove(_ move: Move) -> Bool {
        let promotionChar: String
        if let p = move.promotion {
            promotionChar = String(p.rawValue.lowercased())
        } else {
            promotionChar = ""
        }
        return game.makeMove(moving: "\(move.from)\(move.to)\(promotionChar)")
    }

    /// Legal moves for a given square
    public func legalMoves(from square: Square) -> [Move] {
        let fromNotation = square.description
        let moves = game.legalMoves.filter { $0.contains(fromNotation) }
        return moves.map { uci in
            let fromSq = Square(description: String(uci.prefix(2)))!
            let toSq = Square(description: String(uci.dropFirst(2).prefix(2)))!
            let promChar = uci.count > 4 ? uci.last! : nil
            let prom: PieceKind? = promChar.flatMap { PieceKind(rawValue: String($0).uppercased()) }
            return Move(from: fromSq, to: toSq, promotion: prom, san: uci)
        }
    }

    /// All legal moves
    public var legalMoves: [Move] {
        game.legalMoves.map { uci in
            let fromSq = Square(description: String(uci.prefix(2)))!
            let toSq = Square(description: String(uci.dropFirst(2).prefix(2)))!
            let promChar = uci.count > 4 ? uci.last! : nil
            let prom: PieceKind? = promChar.flatMap { PieceKind(rawValue: String($0).uppercased()) }
            return Move(from: fromSq, to: toSq, promotion: prom, san: uci)
        }
    }

    /// Piece at a given square, if any
    public func piece(at square: Square) -> Piece? {
        guard let piece = game.piece(at: square.description) else { return nil }
        let color: PieceColor = piece.isWhite ? .white : .black
        let kind: PieceKind
        switch piece.letter {
        case "K": kind = .king
        case "Q": kind = .queen
        case "R": kind = .rook
        case "B": kind = .bishop
        case "N": kind = .knight
        case "P": kind = .pawn
        default: return nil
        }
        return Piece(kind: kind, color: color)
    }

    /// Undo last move
    public mutating func undoMove() {
        game.undo()
    }

    /// Set up a custom position from FEN
    public mutating func setFen(_ fen: String) {
        if let g = Chess.Game(fen: fen) {
            self.game = g
        }
    }
}
