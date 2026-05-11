import Foundation

// MARK: - Square

public struct Square: Hashable, Codable, CustomStringConvertible {
    public let file: Int  // 0=a, 7=h
    public let rank: Int  // 0=1, 7=8

    public var index: Int { rank * 8 + file }

    public var description: String {
        let fileChar = Character(UnicodeScalar(97 + file)!)
        return "\(fileChar)\(rank + 1)"
    }

    public static let allSquares: [Square] = {
        (0..<8).flatMap { rank in
            (0..<8).map { file in Square(file: file, rank: rank) }
        }
    }()

    public init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    public init?(description: String) {
        guard description.count == 2 else { return nil }
        let chars = Array(description)
        guard let f = chars[0].asciiValue, f >= 97, f <= 104,
              let r = Int(String(chars[1])), r >= 1, r <= 8 else { return nil }
        self.file = Int(f - 97)
        self.rank = r - 1
    }
}
