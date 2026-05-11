import SwiftUI
import Combine
import ChessCoachShared
import ChessCoachEngine
import ChessCoachCoach

@MainActor
final class PlayViewModel: ObservableObject {

    // MARK: - Board State

    @Published var position: Position = Position()
    @Published var fenInput: String = ""
    @Published var moveHistory: [String] = []
    @Published var currentMoveIndex: Int = -1

    // MARK: - Engine Analysis

    @Published var engineLines: [EngineLine] = []
    @Published var isAnalyzing: Bool = false
    @Published var analysisDepth: Int = 20
    @Published var analysisTime: TimeInterval = 5.0
    @Published var useDepthLimit: Bool = true

    // MARK: - Coach

    @Published var coachMessages: [CoachMessage] = []
    @Published var showCoach: Bool = false
    @Published var isGeneratingExplanation: Bool = false

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private weak var engine: ChessEngine?
    private var coachEngine: CoachEngine?

    // MARK: - Setup

    func setEngine(_ engine: ChessEngine?) {
        self.engine = engine
        if let e = engine {
            self.coachEngine = CoachEngine(engine: e)
        }
    }

    // MARK: - Position Loading

    func loadFen() {
        let fen = fenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fen.isEmpty else { return }
        position = Position(fen: fen)
        moveHistory = []
        currentMoveIndex = -1
        engineLines = []
        coachMessages = []
        showCoach = false
        if isAnalyzing { startAnalysis() }
    }

    func loadStartingPosition() {
        position = Position()
        fenInput = position.fen
        moveHistory = []
        currentMoveIndex = -1
        engineLines = []
        coachMessages = []
        showCoach = false
        if isAnalyzing { startAnalysis() }
    }

    // MARK: - Move Handling

    /// Called when the user makes a move on the board.
    func makeMove(_ move: Move) {
        var pos = position
        do {
            try pos.makeMove(move)
        } catch {
            return
        }
        let positionBefore = position
        position = pos

        // Record UCI in history
        var uci = move.from.description + move.to.description
        if let promo = move.promotion {
            uci += String(promo.rawValue)
        }
        moveHistory.append(uci)
        currentMoveIndex = moveHistory.count - 1

        // Generate coach explanation for this move
        generateCoachExplanation(for: move, positionBefore: positionBefore)

        if isAnalyzing { startAnalysis() }
    }

    /// Called when the engine makes a move (auto-play mode).
    func makeEngineMove(_ uci: String) {
        guard uci.count >= 4 else { return }
        let fromStr = String(uci.prefix(2))
        let toStr = String(uci.dropFirst(2).prefix(2))
        let promoKind: PieceKind? = uci.count == 5
            ? PieceKind(rawValue: String(uci.last!))
            : nil

        guard let from = Square(description: fromStr),
              let to = Square(description: toStr) else { return }

        let move = Move(from: from, to: to, promotion: promoKind)
        var pos = position
        do {
            try pos.makeMove(move)
        } catch {
            return
        }
        position = pos
        moveHistory.append(uci)
        currentMoveIndex = moveHistory.count - 1

        if isAnalyzing { startAnalysis() }
    }

    // MARK: - Coach Explanation

    /// Runs multi-line analysis and generates coach messages for the user's last move.
    private func generateCoachExplanation(for move: Move, positionBefore: Position) {
        guard let eng = engine, eng.isAvailable else { return }
        guard let coach = coachEngine else { return }

        isGeneratingExplanation = true
        coachMessages = []

        var allLines: [EngineLine] = []

        eng.startAnalysis(fen: positionBefore.fen, depth: 18, timeout: 4.0)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] (_: Subscribers.Completion<Never>) in
                    guard let self = self else { return }

                    let bestLine: EngineLine? = allLines.max { a, b in
                        self.scoreValue(a.score) < self.scoreValue(b.score)
                    }

                    let bestMoveUCI = bestLine?.moves.first
                    var bestMoveObj: Move? = nil

                    if let uci = bestMoveUCI, uci.count >= 4 {
                        let fStr = String(uci.prefix(2))
                        let tStr = String(uci.dropFirst(2).prefix(2))
                        if let f = Square(description: fStr), let t = Square(description: tStr) {
                            let promo: PieceKind? = uci.count == 5
                                ? PieceKind(rawValue: String(uci.last!))
                                : nil
                            bestMoveObj = Move(from: f, to: t, promotion: promo)
                        }
                    }

                    let evalLine = allLines.first(where: { $0.depth >= 1 })
                    let explanations = coach.generateMoveExplanation(
                        move: move,
                        position: positionBefore,
                        engineEval: evalLine ?? EngineLine(
                            depth: 1,
                            score: EngineScore.cp(0),
                            moves: [],
                            pv: ""
                        ),
                        engineCandidates: Array(allLines.prefix(5)),
                        bestMove: bestMoveObj
                    )

                    self.coachMessages = explanations
                    self.showCoach = true
                    self.isGeneratingExplanation = false
                },
                receiveValue: { (line: EngineLine) in
                    if !allLines.contains(where: { $0.depth == line.depth && $0.moves == line.moves }) {
                        allLines.append(line)
                    }
                }
            )
            .store(in: &cancellables)
    }

    /// Extracts a comparable Double from an EngineScore enum.
    private func scoreValue(_ score: EngineScore) -> Double {
        switch score {
        case .cp(let cp):          return Double(cp)
        case .mate(let m):         return m > 0 ? 10000 - Double(m) * 10 : -10000 - Double(m) * 10
        case .upperBound(let cp):  return Double(cp)
        case .lowerBound(let cp):  return Double(cp)
        }
    }

    func dismissCoach() {
        showCoach = false
    }

    // MARK: - Engine Analysis (continuous)

    func startAnalysis() {
        guard let engine = engine, engine.isAvailable else { return }
        isAnalyzing = true
        cancellables.removeAll()

        let depth: Int? = useDepthLimit ? analysisDepth : nil
        let time: TimeInterval? = useDepthLimit ? nil : analysisTime

        engine.startAnalysis(fen: position.fen, depth: depth, timeout: time)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] line in
                guard let self = self else { return }
                if !self.engineLines.contains(where: { $0.depth == line.depth && $0.moves == line.moves }) {
                    if self.engineLines.count >= 3 {
                        self.engineLines.removeFirst()
                    }
                    self.engineLines.append(line)
                    self.engineLines.sort { $0.depth > $1.depth }
                }
            }
            .store(in: &cancellables)
    }

    func stopAnalysis() {
        engine?.stopAnalysis()
        isAnalyzing = false
    }

    func toggleAnalysis() {
        if isAnalyzing {
            stopAnalysis()
        } else {
            startAnalysis()
        }
    }

    var bestMove: String? {
        engineLines.first?.moves.first
    }
}
