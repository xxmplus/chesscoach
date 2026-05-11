import Foundation
import ChessCoachShared
import ChessCoachEngine

// MARK: - MoveQuality

public enum MoveQuality: String {
    case brilliant  = "💡 Brilliant!"
    case great      = "🌟 Great!"
    case good       = "✅ Good"
    case best       = "👑 Best"
    case interesting = "📚 Interesting"
    case dubious    = "🤔 Dubious"
    case mistake    = "❌ Mistake"
    case blunder    = "💥 Blunder"
    case inaccuracy = "⚠️ Inaccuracy"
}

// MARK: - CoachMessage

public struct CoachMessage: Identifiable, Equatable {
    public let id = UUID()
    public let theme: CoachTheme
    public let content: String
    public let priority: CoachMessagePriority
    public let tone: Tone
    public let category: Category
    public let annotation: Annotation?

    public init(
        theme: CoachTheme,
        content: String,
        priority: CoachMessagePriority = .medium,
        tone: Tone = .explanatory,
        category: Category = .moveExplanation,
        annotation: Annotation? = nil
    ) {
        self.theme = theme
        self.content = content
        self.priority = priority
        self.tone = tone
        self.category = category
        self.annotation = annotation
    }

    public enum Tone: String, Equatable {
        case encouraging
        case explanatory
        case cautionary
        case directive
        case reflective
    }

    public enum Category: String, Equatable {
        case praise
        case moveExplanation   = "EXPLANATION"
        case patternSpot       = "PATTERN"
        case warning
        case moveComparison    = "COMPARISON"
        case whatIfAnalysis   = "WHAT IF"
        case tactical
        case exercise
        case principle
        case opening
        case endgame
        case middlegame
        case longTerm         = "LONG-TERM"
        case shortTerm        = "SHORT-TERM"
        case strategic
        case candidateAnalysis = "CANDIDATES"
    }

    public struct Annotation: Equatable {
        public let moveQuality: MoveQuality?
        public let evaluation: Int? // centipawns

        public init(moveQuality: MoveQuality? = nil, evaluation: Int? = nil) {
            self.moveQuality = moveQuality
            self.evaluation = evaluation
        }
    }
}

public enum CoachMessagePriority: Int, Comparable {
    case critical = 0
    case high = 1
    case medium = 2
    case low = 3

    public static func < (lhs: CoachMessagePriority, rhs: CoachMessagePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum CoachTheme: String, Equatable {
    case tactical
    case positional
    case strategic
    case defensive
    case kingSafety  = "KING SAFETY"
    case material
    case initiative
    case trades
}

// MARK: - CoachEngine

public final class CoachEngine {

    private weak var engine: ChessEngine?
    private let learnerLevel: LearnerLevel

    public enum LearnerLevel {
        case beginner
        case intermediate
    }

    public init(engine: ChessEngine? = nil, learnerLevel: LearnerLevel = .beginner) {
        self.engine = engine
        self.learnerLevel = learnerLevel
    }

    // MARK: - Public API

    public func generateMoveExplanation(
        move: Move,
        position: Position,
        engineEval: EngineLine,
        engineCandidates: [EngineLine],
        bestMove: Move?
    ) -> [CoachMessage] {
        let quality = classifyMove(move: move, position: position, engineEval: engineEval)
        var messages: [CoachMessage] = []

        messages.append(verdictMessage(move: move, quality: quality, engineEval: engineEval, position: position))

        let changes = analyzeChanges(move: move, position: position)
        messages.append(explanationMessage(move: move, changes: changes, position: position))

        let themes = identifyThemes(move: move, position: position, quality: quality)
        for theme in themes.prefix(2) {
            messages.append(themeMessage(theme: theme, move: move, changes: changes, position: position))
        }

        let alts = analyzeAlternatives(move: move, position: position, candidates: engineCandidates)
        for alt in alts {
            messages.append(CoachMessage(
                theme: .strategic,
                content: alt,
                priority: .medium,
                tone: .explanatory,
                category: .moveComparison
            ))
        }

        let takeaway = generateTakeaway(move: move, changes: changes, quality: quality, position: position)
        messages.append(CoachMessage(
            theme: .strategic,
            content: takeaway,
            priority: .low,
            tone: .reflective,
            category: .principle
        ))

        return messages
    }

    // MARK: - Verdict

    private func verdictMessage(move: Move, quality: MoveQuality, engineEval: EngineLine, position: Position) -> CoachMessage {
        let content: String
        switch quality {
        case .brilliant:
            content = "💡 Brilliant move! This is the engine's top choice. Keep thinking like this — you saw something special here."
        case .great:
            content = "🌟 Great move! The engine agrees — this was the best or near-best option. Excellent thinking."
        case .good, .best:
            content = "✅ Good move. The engine approves. You found a solid continuation."
        case .interesting:
            content = "📚 Interesting choice. Not the top engine pick, but it has merit — you're thinking creatively."
        case .dubious:
            content = "🤔 This move is a bit questionable. The engine prefers something else, though it's not a critical error."
        case .inaccuracy:
            content = "⚠️ A small inaccuracy. The position is still roughly equal, but there was a more precise continuation."
        case .mistake:
            content = "❌ That was a mistake. The engine shows a better sequence — let's look at what went wrong."
        case .blunder:
            content = "💥 A blunder. That's a significant swing. Don't worry — let's understand what happened and come back stronger."
        }

        return CoachMessage(
            theme: .tactical,
            content: content,
            priority: .critical,
            tone: quality == .blunder || quality == .mistake ? .cautionary : .encouraging,
            category: .praise,
            annotation: CoachMessage.Annotation(moveQuality: quality, evaluation: nil)
        )
    }

    // MARK: - Explanation

    private func explanationMessage(move: Move, changes: MoveChanges, position: Position) -> CoachMessage {
        var parts: [String] = []
        let mover = position.piece(at: move.from)
        let moverName = pieceName(mover?.kind)

        if changes.isCastling {
            parts.append("You castled — one of the most important moves in chess, getting your king to safety and activating your rook.")
        } else if changes.isPromotion {
            parts.append("Promotion! You advanced a pawn to the back rank — this is a game-changing achievement.")
        } else if changes.isCapture && changes.materialDelta > 0 {
            let victim = position.piece(at: move.to)
            let victimName = pieceName(victim?.kind)
            parts.append("You captured the opponent's \(victimName) with your \(moverName) — a material gain.")
        } else if changes.givesCheck {
            parts.append("You put the opponent's king in check — a forcing move that limits their options.")
        } else if mover?.kind == .pawn && abs(move.to.file - move.from.file) > 0 {
            parts.append("You advanced your pawn, \(moverName.lowercased()).")
        } else {
            parts.append("You moved your \(moverName.lowercased()) to \(squareName(move.to).lowercased()).")
        }

        if changes.materialDelta < 0 {
            parts.append("However, you lost \(abs(changes.materialDelta)) pawn(s) of material in the exchange.")
        }

        return CoachMessage(
            theme: .tactical,
            content: parts.joined(separator: " "),
            priority: .high,
            tone: .explanatory,
            category: .moveExplanation
        )
    }

    // MARK: - Quality Classification

    func classifyMove(move: Move, position: Position, engineEval: EngineLine) -> MoveQuality {
        let cp = engineEval.score.centipawns ?? 0

        if cp >= 300 { return .brilliant }
        if cp >= 100 { return .great }
        if cp >= 30  { return .good }
        if cp >= -30 { return .best }
        if cp < -80  { return .blunder }
        if cp < -30  { return .mistake }
        return .inaccuracy
    }

    // MARK: - Change Analysis

    private struct MoveChanges {
        let materialDelta: Int
        let givesCheck: Bool
        let isCapture: Bool
        let isCastling: Bool
        let isPromotion: Bool
    }

    private func analyzeChanges(move: Move, position: Position) -> MoveChanges {
        let piece = position.piece(at: move.from)
        let captured = position.piece(at: move.to)
        let matDelta = pieceValue(captured?.kind) - pieceValue(piece?.kind)
        let isCastle = piece?.kind == .king && abs(move.to.file - move.from.file) == 2

        var copy = position
        _ = copy.makeMove(move)
        // After the move, turn flips — copy.turn is now the opponent's color.
        // isCheck tells us if the side to move (opponent) is in check.
        let givesCheck = copy.isCheck

        return MoveChanges(
            materialDelta: matDelta,
            givesCheck: givesCheck,
            isCapture: captured != nil,
            isCastling: isCastle,
            isPromotion: move.promotion != nil
        )
    }

    private func pieceValue(_ kind: PieceKind?) -> Int {
        switch kind {
        case .pawn:   return 1
        case .knight: return 3
        case .bishop: return 3
        case .rook:   return 5
        case .queen:  return 9
        default:       return 0
        }
    }

    // MARK: - Alternatives

    private func analyzeAlternatives(
        move: Move,
        position: Position,
        candidates: [EngineLine]
    ) -> [String] {
        let moveFromUCI = squareToUCI(move.from)
        let moveToUCI = squareToUCI(move.to)

        for line in candidates.prefix(3) {
            guard let uci = line.moves.first, uci.count >= 4 else { continue }
            // Skip the played move
            if uci.hasPrefix(moveFromUCI + moveToUCI) { continue }

            guard let fromSq = Square(description: String(uci.prefix(2))),
                  let toSq = Square(description: String(uci.dropFirst(2).prefix(2))) else { continue }

            let altMove = Move(from: fromSq, to: toSq)
            let diff = abs(line.score.centipawns ?? 0)

            if diff > 80 {
                let altEval = formatEval(line.score)
                return ["Instead of \(moveName(move, in: position)), consider \(moveName(altMove, in: position)). The engine prefers it significantly (\(altEval))."]
            } else if diff > 30 {
                let altEval = formatEval(line.score)
                return ["\(moveName(altMove, in: position)) was another strong option, evaluated similarly at \(altEval)."]
            }
        }
        return []
    }

    // MARK: - Themes

    private func identifyThemes(move: Move, position: Position, quality: MoveQuality) -> [CoachTheme] {
        let piece = position.piece(at: move.from)
        var themes: [CoachTheme] = []

        if let pk = piece?.kind, pk == .king, abs(move.to.file - move.from.file) == 2 {
            return [.kingSafety]
        }

        var copy = position
        _ = copy.makeMove(move)
        let givesCheck = copy.isCheck

        if givesCheck {
            themes.append(.tactical)
        }

        if position.piece(at: move.to) != nil {
            themes.append(.material)
        }

        if piece?.kind == .pawn { themes.append(.positional) }

        if piece?.kind == .rook && isOpenFile(move.from.file, position: position) {
            themes.append(.strategic)
        }

        if piece?.kind == .knight && isOutpost(move.to, color: position.turn, position: position) {
            themes.append(.positional)
        }

        if quality == .good || quality == .brilliant {
            themes.append(.initiative)
        }

        return themes
    }

    // MARK: - Theme Insights

    private func themeMessage(theme: CoachTheme, move: Move, changes: MoveChanges, position: Position) -> CoachMessage {
        let content: String
        switch theme {
        case .kingSafety:
            content = "You castled! This is one of the most important moves in chess — king safety and an active rook. Always prioritize getting your king to safety early."

        case .tactical:
            if changes.givesCheck {
                content = "You put your opponent in check — a forcing move that limits their options. Checks are powerful because they force a response."
            } else {
                let capMsg = changes.isCapture
                    ? " You won \(materialNoun(position.piece(at: move.to))) in the process."
                    : ""
                content = "This move creates a tactical threat.\(capMsg) Always be on the lookout for these patterns — they win material."
            }

        case .positional:
            content = "This move improves your position without immediate tactics. It's about long-term advantage — better structure, more active pieces, control of key squares."

        case .strategic:
            let piece = position.piece(at: move.from)
            if piece?.kind == .rook && isOpenFile(move.from.file, position: position) {
                content = "Your rook now controls an open file — a key strategic asset. Rooks on open files are powerful, especially in the middlegame."
            } else {
                content = "Strategically, this move works toward a long-term plan. Patience and positioning now can pay off later."
            }

        case .defensive:
            content = "This move addresses a threat or strengthens your position defensively. Good defensive awareness is essential at every level."

        case .material:
            if changes.materialDelta > 0 {
                content = "You gained material with this move. Material advantage is one of the most reliable ways to win — convert it carefully!"
            } else {
                content = "This move involves material considerations. Be aware of exchanges and their consequences."
            }

        case .initiative:
            content = "You seized the initiative with this move! Pressing your advantage while you have momentum is how you convert a lead."

        case .trades:
            content = "This move simplifies the position by trading pieces. Sometimes reducing the complexity is the smartest path to victory."
        }

        return CoachMessage(
            theme: theme,
            content: content,
            priority: theme == .tactical || theme == .material ? .high : .medium,
            tone: .explanatory,
            category: theme == .tactical ? .tactical : .principle
        )
    }

    // MARK: - Takeaway

    private func generateTakeaway(move: Move, changes: MoveChanges, quality: MoveQuality, position: Position) -> String {
        if changes.isCastling {
            return "Remember: castling early is one of the most important goals in the opening. Protecting your king and connecting your rooks should be a top priority."
        }
        if changes.givesCheck && quality == .brilliant {
            return "Key takeaway: Checks are forcing moves. Always consider whether a check might win material, gain tempo, or restrict your opponent's king."
        }
        if changes.isCapture && changes.materialDelta > 0 {
            return "Key takeaway: When you win material, your next goal is to convert that advantage. Trade pieces (not pawns) to simplify and edge toward victory."
        }
        if quality == .blunder || quality == .mistake {
            return "Key takeaway: Every mistake is a learning opportunity. Try to identify the moment you went wrong and understand why — that's how you improve."
        }
        return "Key takeaway: Keep practicing pattern recognition. The more positions you see, the faster and more accurate your decisions will become."
    }

    // MARK: - Helpers

    private func isOpenFile(_ file: Int, position: Position) -> Bool {
        for rank in 0..<8 {
            let sq = Square(file: file, rank: rank)
            if let piece = position.piece(at: sq), piece.kind == .pawn, piece.color == position.turn {
                return false
            }
        }
        return true
    }

    private func isOutpost(_ square: Square, color: PieceColor, position: Position) -> Bool {
        let enemyColor: PieceColor = color == .white ? .black : .white
        for df in [-1, 1] {
            let pawnFile = square.file + df
            let pawnRank = color == .white ? square.rank - 1 : square.rank + 1
            guard pawnFile >= 0 && pawnFile < 8 && pawnRank >= 0 && pawnRank < 8 else { continue }
            let pawnSq = Square(file: pawnFile, rank: pawnRank)
            if let piece = position.piece(at: pawnSq), piece.kind == .pawn, piece.color == enemyColor {
                return false
            }
        }
        if let piece = position.piece(at: square), piece.kind == .knight {
            return true
        }
        return false
    }

    private func squareToUCI(_ sq: Square) -> String {
        let files = "abcdefgh"
        let ranks = "12345678"
        return String(files[files.index(files.startIndex, offsetBy: sq.file)]) +
               String(ranks[ranks.index(ranks.startIndex, offsetBy: sq.rank)])
    }

    private func moveName(_ move: Move, in position: Position) -> String {
        let piece = position.piece(at: move.from)
        let pieceName = self.pieceName(piece?.kind).lowercased()
        let to = squareName(move.to)
        if let prom = move.promotion {
            return "\(pieceName) to \(to) promoting to \(self.pieceName(prom))"
        }
        return "\(pieceName) to \(to)"
    }

    private func squareName(_ sq: Square) -> String {
        let files = "abcdefgh"
        let ranks = "12345678"
        return String(files[files.index(files.startIndex, offsetBy: sq.file)]) +
               String(ranks[ranks.index(ranks.startIndex, offsetBy: sq.rank)])
    }

    private func pieceName(_ kind: PieceKind?) -> String {
        switch kind {
        case .pawn:   return "Pawn"
        case .knight: return "Knight"
        case .bishop: return "Bishop"
        case .rook:   return "Rook"
        case .queen:  return "Queen"
        case .king:   return "King"
        case nil:     return "Piece"
        }
    }

    private func materialNoun(_ piece: Piece?) -> String {
        if let p = piece {
            return pieceName(p.kind).lowercased()
        }
        return "material"
    }

    private func formatEval(_ score: EngineScore) -> String {
        switch score {
        case .cp(let cp):
            if cp >= 0 {
                return "+\(String(format: "%.1f", Double(cp) / 100.0))"
            } else {
                return String(format: "%.1f", Double(cp) / 100.0)
            }
        case .mate(let plies):
            return plies > 0 ? "M\(plies)" : "M\(abs(plies))"
        default:
            return score.displayString
        }
    }
}
