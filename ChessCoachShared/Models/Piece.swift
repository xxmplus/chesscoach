import Foundation

// MARK: - Piece

public enum PieceKind: String, Codable, CaseIterable {
    case king = "K"
    case queen = "Q"
    case rook = "R"
    case bishop = "B"
    case knight = "N"
    case pawn = "P"
}

public enum PieceColor: String, Codable {
    case white
    case black
}

public struct Piece: Codable, Hashable, Identifiable {
    public let kind: PieceKind
    public let color: PieceColor

    public var id: String { "\(color.rawValue)\(kind.rawValue)" }

    public var symbol: String {
        let s: String
        switch kind {
        case .king:   s = "K"
        case .queen:  s = "Q"
        case .rook:   s = "R"
        case .bishop: s = "B"
        case .knight: s = "N"
        case .pawn:   s = "P"
        }
        return color == .white ? s : s.lowercased()
    }

    public var character: String {
        switch (kind, color) {
        case (.king,   .white): return "♔"
        case (.queen,  .white): return "♕"
        case (.rook,   .white): return "♖"
        case (.bishop, .white): return "♗"
        case (.knight, .white): return "♘"
        case (.pawn,   .white): return "♙"
        case (.king,   .black): return "♚"
        case (.queen,  .black): return "♛"
        case (.rook,   .black): return "♜"
        case (.bishop, .black): return "♝"
        case (.knight, .black): return "♞"
        case (.pawn,   .black): return "♟"
        }
    }

    public init(kind: PieceKind, color: PieceColor) {
        self.kind = kind
        self.color = color
    }
}
