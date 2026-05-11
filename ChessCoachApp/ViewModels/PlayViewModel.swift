import SwiftUI
import Combine
import ChessCoachShared
import ChessCoachEngine

@MainActor
final class PlayViewModel: ObservableObject {
    @Published var position: Position = Position()
    @Published var fenInput: String = ""
    @Published var engineLines: [EngineLine] = []
    @Published var isAnalyzing: Bool = false
    @Published var analysisDepth: Int = 20
    @Published var analysisTime: TimeInterval = 5.0
    @Published var useDepthLimit: Bool = true
    @Published var moveHistory: [String] = []
    @Published var currentMoveIndex: Int = -1

    private var cancellables = Set<AnyCancellable>()
    private weak var engine: ChessEngine?

    func setEngine(_ engine: ChessEngine?) {
        self.engine = engine
    }

    func loadFen() {
        let fen = fenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fen.isEmpty else { return }
        position = Position(fen: fen)
        moveHistory = []
        currentMoveIndex = -1
        if isAnalyzing { startAnalysis() }
    }

    func loadStartingPosition() {
        position = Position()
        fenInput = position.fen
        moveHistory = []
        currentMoveIndex = -1
        if isAnalyzing { startAnalysis() }
    }

    func makeMove(_ move: Move) {
        var newPos = position
        _ = newPos.makeMove(move)
        position = newPos
        moveHistory.append(move.from.description + move.to.description)
        currentMoveIndex = moveHistory.count - 1
        if isAnalyzing { startAnalysis() }
    }

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
                }
            }
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
