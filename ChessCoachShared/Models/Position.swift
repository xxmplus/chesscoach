import Foundation

// MARK: - Position

/// A self-contained chess position with FEN support, legal move generation,
/// and full game-state detection (check, checkmate, stalemate).
/// No external chess library required.
public struct Position {

    // MARK: - Board Representation

    /// 8×8 board. Index `[rank][file]` where rank 0 = rank 1 (white's back rank), file 0 = file a.
    /// `nil` = empty square.
    private var board: [[Piece?]]

    /// Active side to move
    public var turn: PieceColor

    /// Castling rights (K/k = white/black kingside, Q/q = white/black queenside)
    private var castling: String

    /// En passant target square, if any (e.g. "e3")
    private var enPassant: String?

    /// Halfmove clock (for 50-move rule)
    private var halfmoveClock: Int

    /// Fullmove number
    private var fullmoveNumber: Int

    /// Move history for undo
    private var history: [(board: [[Piece?]], castling: String, enPassant: String?, halfmoveClock: Int)]

    // MARK: - FEN Constants

    public static let startingFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    // MARK: - Public FEN Interface

    public var fen: String {
        var rows: [String] = []
        for rank in 0..<8 {
            var row = ""
            var empty = 0
            for file in 0..<8 {
                if let p = board[rank][file] {
                    if empty > 0 { row += "\(empty)"; empty = 0 }
                    let c = p.color == .white ? p.kind.rawValue.uppercased() : p.kind.rawValue.lowercased()
                    row += c
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += "\(empty)" }
            rows.append(row)
        }
        let placement = rows.joined(separator: "/")
        let color = turn == .white ? "w" : "b"
        let castlingStr = castling.isEmpty ? "-" : castling
        let epStr = enPassant ?? "-"
        return "\(placement) \(color) \(castlingStr) \(epStr) \(halfmoveClock) \(fullmoveNumber)"
    }

    // MARK: - Initializers

    public init(fen: String = Position.startingFen) {
        self.board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        self.turn = .white
        self.castling = ""
        self.enPassant = nil
        self.halfmoveClock = 0
        self.fullmoveNumber = 1
        self.history = []
        parseFen(fen)
    }

    // MARK: - FEN Parsing

    private mutating func parseFen(_ fen: String) {
        let parts = fen.split(separator: " ").map(String.init)
        guard parts.count >= 1 else { return }
        let ranks = parts[0].split(separator: "/").map(String.init)
        for (rankIdx, rank) in ranks.enumerated() {
            var file = 0
            for ch in rank {
                if let d = Int(String(ch)) {
                    file += d
                } else {
                    let color: PieceColor = ch.isUppercase ? .white : .black
                    let kindStr = String(ch).uppercased()
                    if let kind = PieceKind(rawValue: kindStr) {
                        board[7 - rankIdx][file] = Piece(kind: kind, color: color)
                    }
                    file += 1
                }
            }
        }
        if parts.count >= 2 { turn = parts[1] == "w" ? .white : .black }
        if parts.count >= 3 { castling = parts[2] }
        if parts.count >= 4 { enPassant = parts[3] == "-" ? nil : parts[3] }
        if parts.count >= 5 { halfmoveClock = Int(parts[4]) ?? 0 }
        if parts.count >= 6 { fullmoveNumber = Int(parts[5]) ?? 1 }
    }

    // MARK: - Board Queries

    /// Piece at a given square, if any
    public func piece(at square: Square) -> Piece? {
        let r = square.rank, f = square.file
        guard r >= 0 && r < 8 && f >= 0 && f < 8 else { return nil }
        return board[r][f]
    }

    private func kingSquare(for color: PieceColor) -> Square? {
        for r in 0..<8 {
            for f in 0..<8 {
                if let p = board[r][f], p.kind == .king && p.color == color {
                    return Square(file: f, rank: r)
                }
            }
        }
        return nil
    }

    private func isSquareAttacked(_ sq: Square, by color: PieceColor) -> Bool {
        let r = sq.rank, f = sq.file

        // Pawn attacks
        let pawnDir = color == .white ? 1 : -1
        for df in [-1, 1] {
            let nr = r + pawnDir, nf = f + df
            if nr >= 0 && nr < 8 && nf >= 0 && nf < 8,
               let p = board[nr][nf],
               p.color == color && p.kind == .pawn {
                return true
            }
        }

        // Knight attacks
        let knightOffsets = [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)]
        for (dr, df) in knightOffsets {
            let nr = r + dr, nf = f + df
            if nr >= 0 && nr < 8 && nf >= 0 && nf < 8,
               let p = board[nr][nf],
               p.color == color && p.kind == .knight {
                return true
            }
        }

        // King attacks
        for dr in -1...1 {
            for df in -1...1 {
                if dr == 0 && df == 0 { continue }
                let nr = r + dr, nf = f + df
                if nr >= 0 && nr < 8 && nf >= 0 && nf < 8,
                   let p = board[nr][nf],
                   p.color == color && p.kind == .king {
                    return true
                }
            }
        }

        // Sliding pieces
        let rookDirs = [(-1,0),(1,0),(0,-1),(0,1)]
        let bishopDirs = [(-1,-1),(-1,1),(1,-1),(1,1)]

        for (dr, df) in rookDirs {
            var nr = r + dr, nf = f + df
            while nr >= 0 && nr < 8 && nf >= 0 && nf < 8 {
                if let p = board[nr][nf] {
                    if p.color == color && (p.kind == .rook || p.kind == .queen) { return true }
                    break
                }
                nr += dr; nf += df
            }
        }

        for (dr, df) in bishopDirs {
            var nr = r + dr, nf = f + df
            while nr >= 0 && nr < 8 && nf >= 0 && nf < 8 {
                if let p = board[nr][nf] {
                    if p.color == color && (p.kind == .bishop || p.kind == .queen) { return true }
                    break
                }
                nr += dr; nf += df
            }
        }

        return false
    }

    private func isAttacked(_ sq: Square) -> Bool {
        isSquareAttacked(sq, by: turn == .white ? .black : .white)
    }

    // MARK: - Game State

    public var isCheck: Bool {
        guard let kingSq = kingSquare(for: turn) else { return false }
        return isAttacked(kingSq)
    }

    public var isCheckmate: Bool {
        return isCheck && legalMoves.isEmpty
    }

    public var isStalemate: Bool {
        return !isCheck && legalMoves.isEmpty
    }

    public var isGameOver: Bool {
        return isCheckmate || isStalemate
    }

    // MARK: - Move Generation

    public var legalMoves: [Move] {
        var moves: [Move] = []
        for r in 0..<8 {
            for f in 0..<8 {
                guard let p = board[r][f], p.color == turn else { continue }
                let from = Square(file: f, rank: r)
                moves.append(contentsOf: legalMoves(from: from))
            }
        }
        return moves
    }

    public func legalMoves(from square: Square) -> [Move] {
        let r = square.rank, f = square.file
        guard let piece = board[r][f], piece.color == turn else { return [] }

        let pseudo = pseudoLegalMoves(from: square, piece: piece)
        return pseudo.filter { move in
            var copy = self
            copy.applyMove(move)
            let opponentColor: PieceColor = turn == .white ? .black : .white
            guard let oppKing = copy.kingSquare(for: opponentColor) else { return false }
            let attackerColor: PieceColor = turn == .white ? .white : .black
            return !copy.isSquareAttacked(oppKing, by: attackerColor)
        }
    }

    private func pseudoLegalMoves(from: Square, piece: Piece) -> [Move] {
        let r = from.rank, f = from.file
        var moves: [Move] = []

        switch piece.kind {
        case .pawn:
            moves = pawnMoves(rank: r, file: f, color: piece.color)
        case .knight:
            moves = knightMoves(rank: r, file: f, color: piece.color)
        case .bishop:
            moves = slidingMoves(rank: r, file: f, dirs: [(-1,-1),(-1,1),(1,-1),(1,1)], color: piece.color)
        case .rook:
            moves = slidingMoves(rank: r, file: f, dirs: [(-1,0),(1,0),(0,-1),(0,1)], color: piece.color)
        case .queen:
            moves = slidingMoves(rank: r, file: f, dirs: [(-1,-1),(-1,1),(1,-1),(1,1),(-1,0),(1,0),(0,-1),(0,1)], color: piece.color)
        case .king:
            moves = kingMoves(rank: r, file: f, color: piece.color)
        }
        return moves
    }

    private func pawnMoves(rank: Int, file: Int, color: PieceColor) -> [Move] {
        var moves: [Move] = []
        let dir: Int = color == .white ? 1 : -1
        let startRow: Int = color == .white ? 1 : 6
        let promoRow: Int = color == .white ? 7 : 0
        let from = Square(file: file, rank: rank)

        // Single push
        let nr = rank + dir
        if nr >= 0 && nr < 8 && board[nr][file] == nil {
            if nr == promoRow {
                for prom in [PieceKind.queen, .rook, .bishop, .knight] {
                    moves.append(Move(from: from, to: Square(file: file, rank: nr), promotion: prom))
                }
            } else {
                moves.append(Move(from: from, to: Square(file: file, rank: nr)))
            }
            // Double push
            if rank == startRow {
                let nr2 = rank + 2 * dir
                if board[nr2][file] == nil {
                    moves.append(Move(from: from, to: Square(file: file, rank: nr2)))
                }
            }
        }

        // Captures
        for df in [-1, 1] {
            let nf = file + df
            if nf < 0 || nf >= 8 || nr < 0 || nr >= 8 { continue }
            if let target = board[nr][nf], target.color != color {
                if nr == promoRow {
                    for prom in [PieceKind.queen, .rook, .bishop, .knight] {
                        moves.append(Move(from: from, to: Square(file: nf, rank: nr), promotion: prom))
                    }
                } else {
                    moves.append(Move(from: from, to: Square(file: nf, rank: nr)))
                }
            } else if nf == file && nr >= 0 && nr < 8 {
                // En passant
                let epSq = Square(file: nf, rank: nr)
                if epSq.description == enPassant {
                    moves.append(Move(from: from, to: epSq, enPassant: true))
                }
            }
        }
        return moves
    }

    private func knightMoves(rank: Int, file: Int, color: PieceColor) -> [Move] {
        let offsets = [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)]
        return slidingPieceMoves(rank: rank, file: file, offsets: offsets, color: color)
    }

    private func kingMoves(rank: Int, file: Int, color: PieceColor) -> [Move] {
        let offsets = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
        return slidingPieceMoves(rank: rank, file: file, offsets: offsets, color: color)
    }

    private func slidingMoves(rank: Int, file: Int, dirs: [(Int, Int)], color: PieceColor) -> [Move] {
        return slidingPieceMoves(rank: rank, file: file, offsets: dirs, color: color)
    }

    private func slidingPieceMoves(rank: Int, file: Int, offsets: [(Int, Int)], color: PieceColor) -> [Move] {
        var moves: [Move] = []
        let from = Square(file: file, rank: rank)
        for (dr, df) in offsets {
            let nr = rank + dr, nf = file + df
            if nr >= 0 && nr < 8 && nf >= 0 && nf < 8 {
                let to = Square(file: nf, rank: nr)
                if let p = board[nr][nf] {
                    if p.color != color { moves.append(Move(from: from, to: to)) }
                } else {
                    moves.append(Move(from: from, to: to))
                }
            }
        }
        return moves
    }

    // MARK: - Move Application

    public mutating func makeMove(uci: String) -> Bool {
        guard uci.count >= 4 else { return false }
        let fromStr = String(uci.prefix(2))
        let toStr = String(uci.dropFirst(2).prefix(2))
        guard let from = Square(description: fromStr),
              let to = Square(description: toStr) else { return false }
        let promotion: PieceKind?
        if uci.count > 4, let pChar = uci.last {
            promotion = PieceKind(rawValue: String(pChar).uppercased())
        } else {
            if let p = piece(at: from), p.kind == .pawn && (to.rank == 7 || to.rank == 0) {
                promotion = .queen
            } else {
                promotion = nil
            }
        }
        let move = Move(from: from, to: to, promotion: promotion)
        let legal = legalMoves(from: from).contains { $0.from == from && $0.to == to && $0.promotion == promotion }
        if legal { applyMove(move); return true }
        return false
    }

    public mutating func makeMove(_ move: Move) -> Bool {
        let legal = legalMoves(from: move.from).contains {
            $0.from == move.from && $0.to == move.to && $0.promotion == move.promotion
        }
        if legal { applyMove(move); return true }
        return false
    }

    private mutating func applyMove(_ move: Move) {
        history.append((board: board.map { $0 }, castling: castling, enPassant: enPassant, halfmoveClock: halfmoveClock))

        let r = move.from.rank, f = move.from.file
        let nr = move.to.rank, nf = move.to.file
        guard var piece = board[r][f] else { return }

        // En passant capture
        if piece.kind == .pawn && move.enPassant {
            let captureRank = turn == .white ? nr + 1 : nr - 1
            board[captureRank][nf] = nil
        }

        // Promotion
        if let prom = move.promotion {
            piece = Piece(kind: prom, color: piece.color)
        }

        board[nr][nf] = piece
        board[r][f] = nil

        // Castling
        if piece.kind == .king && abs(f - nf) == 2 {
            if nf == 6 {
                board[nr][5] = board[nr][7]; board[nr][7] = nil
            } else if nf == 2 {
                board[nr][3] = board[nr][0]; board[nr][0] = nil
            }
        }

        // Update castling rights
        if piece.kind == .king {
            castling = turn == .white
                ? castling.replacingOccurrences(of: "K", with: "").replacingOccurrences(of: "Q", with: "")
                : castling.replacingOccurrences(of: "k", with: "").replacingOccurrences(of: "q", with: "")
        }
        if piece.kind == .rook {
            if r == 0 && f == 0 { castling = castling.replacingOccurrences(of: "Q", with: "") }
            if r == 0 && f == 7 { castling = castling.replacingOccurrences(of: "K", with: "") }
            if r == 7 && f == 0 { castling = castling.replacingOccurrences(of: "q", with: "") }
            if r == 7 && f == 7 { castling = castling.replacingOccurrences(of: "k", with: "") }
        }
        if nr == 0 && nf == 0 { castling = castling.replacingOccurrences(of: "Q", with: "") }
        if nr == 0 && nf == 7 { castling = castling.replacingOccurrences(of: "K", with: "") }
        if nr == 7 && nf == 0 { castling = castling.replacingOccurrences(of: "q", with: "") }
        if nr == 7 && nf == 7 { castling = castling.replacingOccurrences(of: "k", with: "") }

        // En passant square
        if piece.kind == .pawn && abs(r - nr) == 2 {
            let epRank = turn == .white ? nr - 1 : nr + 1
            enPassant = Square(file: f, rank: epRank).description
        } else {
            enPassant = nil
        }

        // Clocks
        halfmoveClock = (piece.kind == .pawn || board[nr][nf] != nil) ? 0 : halfmoveClock + 1
        if turn == .black { fullmoveNumber += 1 }

        turn = turn == .white ? .black : .white
    }

    public mutating func undoMove() {
        guard let state = history.popLast() else { return }
        board = state.board
        castling = state.castling
        enPassant = state.enPassant
        halfmoveClock = state.halfmoveClock
        turn = turn == .white ? .black : .white
        if turn == .white { fullmoveNumber = max(1, fullmoveNumber - 1) }
    }

    public mutating func setFen(_ fen: String) {
        board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        turn = .white; castling = ""; enPassant = nil; halfmoveClock = 0; fullmoveNumber = 1; history = []
        parseFen(fen)
    }
}

// MARK: - Codable

extension Position: Codable {
    enum CodingKeys: String, CodingKey {
        case board, turn, castling, enPassant, halfmoveClock, fullmoveNumber
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let boardStrings = try container.decode([[String]].self, forKey: .board)
        var b: [[Piece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        for r in 0..<8 {
            for f in 0..<8 {
                let token = boardStrings[r][f]
                if !token.isEmpty, let first = token.first {
                    let color: PieceColor = first.isUppercase ? .white : .black
                    if let kind = PieceKind(rawValue: String(first).uppercased()) {
                        b[r][f] = Piece(kind: kind, color: color)
                    }
                }
            }
        }
        self.board = b
        self.turn = try container.decode(PieceColor.self, forKey: .turn)
        self.castling = try container.decode(String.self, forKey: .castling)
        self.enPassant = try container.decodeIfPresent(String.self, forKey: .enPassant)
        self.halfmoveClock = try container.decode(Int.self, forKey: .halfmoveClock)
        self.fullmoveNumber = try container.decode(Int.self, forKey: .fullmoveNumber)
        self.history = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var boardStrings: [[String]] = Array(repeating: Array(repeating: "", count: 8), count: 8)
        for r in 0..<8 {
            for f in 0..<8 {
                if let p = board[r][f] {
                    boardStrings[r][f] = p.color == .white ? p.kind.rawValue.uppercased() : p.kind.rawValue.lowercased()
                }
            }
        }
        try container.encode(boardStrings, forKey: .board)
        try container.encode(turn, forKey: .turn)
        try container.encode(castling, forKey: .castling)
        try container.encodeIfPresent(enPassant, forKey: .enPassant)
        try container.encode(halfmoveClock, forKey: .halfmoveClock)
        try container.encode(fullmoveNumber, forKey: .fullmoveNumber)
    }
}

// MARK: - Equatable

extension Position: Equatable {
    public static func == (lhs: Position, rhs: Position) -> Bool {
        lhs.fen == rhs.fen
    }
}
