import Foundation

// MARK: - ContentLoader

/// Loads lesson and puzzle content from bundled JSON assets.
public final class ContentLoader {
    public static let shared = ContentLoader()

    private init() {}

    // MARK: - Lessons

    public func loadLessons() -> [Lesson] {
        // If a bundled asset exists, load from it; otherwise return built-in defaults
        if let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(LessonsPayload.self, from: data) {
            return decoded.lessons
        }
        return Self.builtInLessons
    }

    // MARK: - Puzzles

    public func loadPuzzles() -> [Puzzle] {
        if let url = Bundle.main.url(forResource: "puzzles", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(PuzzlesPayload.self, from: data) {
            return decoded.puzzles
        }
        return Self.builtInPuzzles
    }

    public func puzzles(for rating: Int, limit: Int = 10) -> [Puzzle] {
        let all = loadPuzzles()
        let range = (rating - 200)...(rating + 200)
        let filtered = all.filter { range.contains($0.rating) }
        return Array(filtered.prefix(limit))
    }

    public func nextPuzzle(for rating: Int) -> Puzzle? {
        puzzles(for: rating, limit: 20).randomElement()
    }

    // MARK: - Built-in Lessons (curriculum)

    private static let builtInLessons: [Lesson] = [
        // ── OPENING ──────────────────────────────────────────────
        Lesson(
            id: "op-001",
            phase: .opening,
            title: "The Italian Game",
            difficulty: 1000,
            body: """
            <h2>The Italian Game (1.e4 e5 2.Nf3 Nc6 3.Bc4)</h2>
            <p>One of the oldest documented openings. White develops the bishop to c4, attacking the vulnerable f7 square.</p>
            <p><b>Key idea:</b> Control the centre and eye the f7 pawn. If Black plays ...d5, consider Bxd5 — but don't rush.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "rnbqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3",
                    description: "Position after 1.e4 e5 2.Nf3 Nc6 3.Bc4. The Italian bishop eyes f7."
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        ),
        Lesson(
            id: "op-002",
            phase: .opening,
            title: "The Sicilian Defense",
            difficulty: 900,
            body: """
            <h2>The Sicilian Defense (1.e4 c5)</h2>
            <p>The most popular reply to 1.e4. Black immediately fights for the centre with an asymmetric pawn structure.</p>
            <p><b>Key idea:</b> Black accepts an isolated queen's pawn (isolani) but gains activity. White gets a central majority.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
                    description: "The starting Sicilian. Black's c5 pawn fights e4."
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        ),
        Lesson(
            id: "op-003",
            phase: .opening,
            title: "Development Principles",
            difficulty: 800,
            body: """
            <h2>Opening Principles</h2>
            <p>Every chess opening follows these rules:</p>
            <ol>
            <li><b>Control the centre</b> — occupy or attack the e4, d4, e5, d5 squares</li>
            <li><b>Develop your pieces</b> — knights before bishops, get all pieces out</li>
            <li><b>King safety</b> — don't castle into an attack; don't move the same piece twice</li>
            <li><b>Don't weaken your pawn structure</b> — avoid moving the same pawn twice or creating holes</li>
            </ol>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
                    description: "The starting position. Where should Black respond to 1.e4?"
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 2, two: 1, three: 1)
        ),

        // ── MIDDLEGAME ────────────────────────────────────────────
        Lesson(
            id: "mg-001",
            phase: .middlegame,
            title: "Forks",
            difficulty: 1100,
            body: """
            <h2>The Fork</h2>
            <p>A fork is when one piece attacks two or more enemy pieces simultaneously. Knights are the most common forking pieces.</p>
            <p><b>Key pattern:</b> The royal fork — a knight attacks the king and queen at the same time. This usually wins the queen.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3",
                    description: "A classic fork setup. Black's knight can fork e4 and g5, or target d5 and f6.",
                    moves: ["e5", "Nf3", "Nc6", "Bc4"]
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        ),
        Lesson(
            id: "mg-002",
            phase: .middlegame,
            title: "Pins and Skewers",
            difficulty: 1150,
            body: """
            <h2>Pins and Skewers</h2>
            <p><b>Pin:</b> An attack along a line where moving the front piece would expose a more valuable piece behind it.</p>
            <p><b>Skewer:</b> The opposite — attacking a valuable piece forces it to move, exposing a less valuable piece behind.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 4 4",
                    description: "White's bishop pins the knight to the king along the diagonal.",
                    moves: nil
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        ),
        Lesson(
            id: "mg-003",
            phase: .middlegame,
            title: "Discovered Attacks",
            difficulty: 1200,
            body: """
            <h2>Discovered Attacks</h2>
            <p>Moving one piece reveals an attack from another piece behind it. Extremely powerful when the hidden piece attacks the king (giving check) or a high-value piece.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "r2qkbnr/ppp2ppp/2np4/4p3/2B1P2b/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5",
                    description: "White's knight on f3 can move to d4 or e5, discovering an attack on the e5 pawn.",
                    moves: nil
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        ),

        // ── ENDGAME ───────────────────────────────────────────────
        Lesson(
            id: "eg-001",
            phase: .endgame,
            title: "Checkmate with Queen",
            difficulty: 900,
            body: """
            <h2>Queen and King vs King</h2>
            <p>The simplest checkmate. Drive the king to the edge using the king as a shield, then deliver mate with the queen.</p>
            <p><b>Rule:</b> Keep the king and queen separated by one square. Approach with the king, bring the queen behind.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "8/8/8/3K4/3Q4/8/8/4k3 w - - 0 1",
                    description: "Queen vs King. Mate in 3 moves: Qd4+, Ke6, Qe5#"
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        ),
        Lesson(
            id: "eg-002",
            phase: .endgame,
            title: "The Opposition",
            difficulty: 1100,
            body: """
            <h2>King Opposition</h2>
            <p>In a pawn endgame, the player who <em>doesn't</em> have the move when kings face each other is often at a disadvantage.</p>
            <p><b>Key idea:</b> When your king blocks the opposing king from advancing, you have the opposition. Use it to push your pawns.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "8/8/8/4k3/4P3/8/8/4K3 w - - 0 1",
                    description: "White to move. Whoever moves first loses the opposition and the e-pawn."
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        ),
        Lesson(
            id: "eg-003",
            phase: .endgame,
            title: "Rook Endgames — Lucena Position",
            difficulty: 1400,
            body: """
            <h2>The Lucena Position</h2>
            <p>The most important rook endgame technique. White wins by building a <em>bridge</em> to shield the rook from the opposing king.</p>
            <p><b>Pattern:</b> King in front of advancing pawn, rook behind — the bridge move Rf6+ lifts the rook over to safety.</p>
            """,
            positions: [
                Lesson.LessonPosition(
                    fen: "8/8/2KP4/1R6/8/8/8/3k4 w - - 0 1",
                    description: "The Lucena Position. White wins with Rb6+ followed by Rd6."
                )
            ],
            starsThresholds: Lesson.StarsThresholds(one: 3, two: 2, three: 1)
        )
    ]

    // MARK: - Built-in Puzzles

    private static let builtInPuzzles: [Puzzle] = [
        // EASY (600-900)
        Puzzle(id: "p-001", fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
               solution: ["h7h6"], themes: ["matingattack"], difficulty: 1, rating: 600,
               hints: ["Black can deliver checkmate in one move", "The h7 pawn can advance to h6, delivering checkmate on the first rank"]),
        Puzzle(id: "p-002", fen: "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
               solution: ["f3e5"], themes: ["fork"], difficulty: 2, rating: 750,
               hints: ["A knight can attack two pieces at once", "The knight on f3 can jump to e5, forking the black king and queen"]),
        Puzzle(id: "p-003", fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
               solution: ["c4f7"], themes: ["checkmate"], difficulty: 2, rating: 800,
               hints: ["The bishop can deliver checkmate on f7", "Black's f7 pawn is defended only by the king"]),

        // MEDIUM (900-1200)
        Puzzle(id: "p-004", fen: "r2qkbnr/ppp2ppp/2np4/4p3/2B1P1b1/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5",
               solution: ["f3e5"], themes: ["fork"], difficulty: 4, rating: 950,
               hints: ["The knight can attack two black pieces", "Moving to e5 attacks both the pawn on d6 and the bishop on g4"]),
        Puzzle(id: "p-005", fen: "r1bqk2r/ppp2ppp/2np1n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 6",
               solution: ["c3d4"], themes: ["opening"], difficulty: 4, rating: 1000,
               hints: ["Central control is key", "Advancing the d-pawn opens the diagonal for the queen"]),

        // HARD (1200-1600)
        Puzzle(id: "p-006", fen: "r1bqkb1r/pppp1ppp/2n5/4p3/2BnP3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
               solution: ["f3e5", "d6e5", "d1h5"], themes: ["tactics", "attack"], difficulty: 6, rating: 1300,
               hints: ["Sacrifice the knight for a devastating attack", "After Nxe5 dxe5, Qh5+ forces checkmate"]),
        Puzzle(id: "p-007", fen: "r2qk2r/ppp2ppp/2n1bn2/3pp3/2B1P1b1/2NP1N2/PPP2PPP/R1BQK2R w KQkq - 0 7",
               solution: ["c4d5"], themes: ["opening", "centrecontrol"], difficulty: 6, rating: 1350,
               hints: ["Strike at the centre", "The pawn fork wins a piece"]),

        // EXPERT (1600-1800)
        Puzzle(id: "p-008", fen: "r1bqr1k1/pp1nbppp/2p2n2/3pp3/2B1P1b1/2NP1N2/PPP1BPPP/R2QK2R w KQ - 0 9",
               solution: ["e4d5", "f6d5", "e1e8", "d8e8", "d3d4"], themes: ["tactics", "exchange"], difficulty: 8, rating: 1650,
               hints: ["Win the exchange with a tactic", "A discovered attack wins the rook"])
    ]
}

// MARK: - Payload types (for JSON decoding)

private struct LessonsPayload: Codable {
    let lessons: [Lesson]
}

private struct PuzzlesPayload: Codable {
    let puzzles: [Puzzle]
}
