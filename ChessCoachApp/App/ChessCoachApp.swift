import SwiftUI
import ChessCoachEngine
import ChessCoachCoach
import ChessCoachShared

@main
struct ChessCoachApp: App {
    @StateObject private var engineManager = EngineManager.shared
    @StateObject private var coachManager = CoachManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environmentObject(engineManager)
                .environmentObject(coachManager)
                .task {
                    await engineManager.initialize()
                    await coachManager.initialize()
                }
        }
    }
}

// MARK: - EngineManager

/// Singleton that manages the active chess engine (Stockfish by default, swappable for Lc0).
@MainActor
final class EngineManager: ObservableObject {
    static let shared = EngineManager()

    @Published private(set) var engine: ChessEngine?
    @Published private(set) var isEngineReady = false
    @Published private(set) var engineName: String = "—"

    private let stockfish = StockfishAdapter()

    private init() {}

    func initialize() async {
        do {
            try await stockfish.initialize()
            self.engine = stockfish
            self.engineName = stockfish.displayName
            self.isEngineReady = true
        } catch {
            print("EngineManager: failed to init Stockfish: \(error)")
        }
    }

    func switchToLc0() async {
        // TODO: swap engine to Lc0 when available
    }

    func switchToStockfish() async {
        if stockfish.isAvailable {
            engine = stockfish
            engineName = stockfish.displayName
        } else {
            do {
                try await stockfish.initialize()
                engine = stockfish
                engineName = stockfish.displayName
            } catch {
                print("EngineManager: failed to switch to Stockfish: \(error)")
            }
        }
    }
}
