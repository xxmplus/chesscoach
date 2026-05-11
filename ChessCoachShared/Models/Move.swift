import Foundation

// MARK: - Move

public struct Move: Codable, Hashable, Identifiable {
    public let from: Square
    public let to: Square
    public let promotion: PieceKind?
    public let san: String  // Standard Algebraic Notation, e.g. "Nxf3+"
    /// True if this is an en passant capture
    public let enPassant: Bool

    public var id: String { "\(from)\(to)\(promotion?.rawValue ?? "")" }

    public init(from: Square, to: Square, promotion: PieceKind? = nil, san: String = "", enPassant: Bool = false) {
        self.from = from
        self.to = to
        self.promotion = promotion
        self.san = san
        self.enPassant = enPassant
    }
}
