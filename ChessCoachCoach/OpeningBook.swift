import Foundation

// MARK: - Opening

public struct Opening: Identifiable, Codable {
    public let id: String
    public let name: String
    public let eco: String           // e.g. "C53" (Sicilian)
    public let fen: String           // Starting position of the opening
    public let moves: [String]       // Canonical move sequence in UCI
    public let description: String
    public let themes: [String]      // e.g. ["open", "tactics"]
    public let difficulty: Int        // Elo estimate

    public var movesSan: String {
        // Placeholder; real conversion needs a SAN engine
        moves.joined(separator: " ")
    }
}

// MARK: - OpeningBook

public final class OpeningBook: ObservableObject {
    @Published public private(set) var openings: [Opening] = []
    @Published public private(set) var bookmarkedOpenings: [String] = [] // Opening IDs

    private let bookmarksKey = "opening_bookmarks"

    public init() {
        load()
    }

    public func load() {
        // Ship with a built-in set of common openings
        openings = Self.builtInOpenings
        bookmarkedOpenings = UserDefaults.standard.stringArray(forKey: bookmarksKey) ?? []
    }

    public func bookmark(_ opening: Opening) {
        if !bookmarkedOpenings.contains(opening.id) {
            bookmarkedOpenings.append(opening.id)
            saveBookmarks()
        }
    }

    public func unbookmark(_ opening: Opening) {
        bookmarkedOpenings.removeAll { $0 == opening.id }
        saveBookmarks()
    }

    public func isBookmarked(_ opening: Opening) -> Bool {
        bookmarkedOpenings.contains(opening.id)
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(bookmarkedOpenings, forKey: bookmarksKey)
    }

    // MARK: - Built-in Opening Library

    private static let builtInOpenings: [Opening] = [
        Opening(
            id: "op-001", name: "Italian Game", eco: "C50",
            fen: "rnbqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3",
            moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4"],
            description: "One of the oldest and most instructive openings. White develops quickly and eyes the vulnerable f7 square.",
            themes: ["open", "development", "attack"],
            difficulty: 1000
        ),
        Opening(
            id: "op-002", name: "Sicilian Defense", eco: "B21",
            fen: "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
            moves: ["e2e4", "c7c5"],
            description: "The most popular response to 1.e4. Black fights for the centre with an asymmetric pawn structure.",
            themes: ["semi-open", "asymmetric", "counterattack"],
            difficulty: 900
        ),
        Opening(
            id: "op-003", name: "Queen's Gambit", eco: "D06",
            fen: "rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR b KQkq - 0 2",
            moves: ["d2d4", "d7d5", "c2c4"],
            description: "White offers a pawn to gain centre control and piece activity. Black can accept or decline.",
            themes: ["closed", "positional", "pawn-structure"],
            difficulty: 1000
        ),
        Opening(
            id: "op-004", name: "King's Indian Defense", eco: "E60",
            fen: "rnbqkbnr/pppppppp/8/8/3PP3/8/PPP2PPP/RNBQKBNR b Kq - 0 1",
            moves: ["d2d4", "g8f6", "c2c4"],
            description: "Black allows White to occupy the centre, then strikes back with ...e5 or ...c5, aiming for complex middlegames.",
            themes: ["hypbrid", "hypermodern", "counterattack"],
            difficulty: 1100
        ),
        Opening(
            id: "op-005", name: "Ruy Lopez", eco: "C60",
            fen: "rnbqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 4 3",
            moves: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4"],
            description: "The 'Spanish Game' — White attacks the e5 pawn and prepares to control the centre. A cornerstone of classical chess.",
            themes: ["open", "development", "strategic"],
            difficulty: 1000
        ),
        Opening(
            id: "op-006", name: "Caro-Kann Defense", eco: "B10",
            fen: "rnbqkbnr/pp1ppppp/2p5/4P3/4P3/8/PPPP2PP/RNBQKBNR b KQkq - 0 2",
            moves: ["e2e4", "c7c6"],
            description: "Solid and positional. Black aims to create a reliable pawn structure while clearing c6 for piece development.",
            themes: ["semi-open", "solid", "hypmodern"],
            difficulty: 900
        ),
        Opening(
            id: "op-007", name: "French Defense", eco: "C00",
            fen: "rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 3",
            moves: ["e2e4", "e7e6"],
            description: "Black challenges White's e4 pawn directly, often leading to rich strategic battles after ...d5.",
            themes: ["semi-open", "strategic", "pawn-structure"],
            difficulty: 900
        ),
        Opening(
            id: "op-008", name: "English Opening", eco: "A10",
            fen: "rnbqkbnr/pppppppp/8/8/2PP4/8/PP2PPPP/RNBQKBNR b KQkq - 0 2",
            moves: ["c2c4"],
            description: "A flexible flank opening. White controls central squares while keeping options open for both sides.",
            themes: ["flank", "flexible", "positional"],
            difficulty: 950
        )
    ]
}
