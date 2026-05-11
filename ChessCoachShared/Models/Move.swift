import Foundation

// MARK: - Move

public struct Move: Codable, Hashable, Identifiable {
    public let from: Square
    public let to: Square
    public let promotion: PieceKind?
    public let san: String  // Standard Algebraic Notation, e.g. "Nxf3+"

    public var id: String { "\(from)\(to)\(promotion?.rawValue ?? "")" }

    public init(from: Square, to: Square, promotion: PieceKind? = nil, san: String = "") {
        self.from = from
        self.to = to
        self.promotion = promotion
        self.san = san
    }
}
