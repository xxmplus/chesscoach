import XCTest
import Combine
@testable import ChessCoachEngine
@testable import ChessCoachShared

final class EngineInfrastructureTests: XCTestCase {

    func testLLMCoachingPromptFormatsCentipawnScoreWithSignAndAlternatives() {
        let prompt = LLMCoachingPrompt(
            score: .cp(42),
            bestMove: "e2e4",
            alternatives: [
                (move: "d2d4", score: .cp(31)),
                (move: "g1f3", score: .cp(-12)),
                (move: "c2c4", score: .mate(3)),
                (move: "b1c3", score: .cp(5))
            ],
            playerColor: .white
        )

        let text = prompt.promptString

        XCTAssertTrue(text.contains("White to move"))
        XCTAssertTrue(text.contains("+0.42 pawns"))
        XCTAssertTrue(text.contains("Best move: e2e4"))
        XCTAssertTrue(text.contains("d2d4 (+0.31)"))
        XCTAssertTrue(text.contains("g1f3 (-0.12)"))
        XCTAssertTrue(text.contains("c2c4 (M3)"))
        XCTAssertFalse(text.contains("b1c3"), "Only first three alternatives should be included")
        XCTAssertTrue(text.contains("Write exactly 2 sentences"))
    }

    func testLLMCoachingPromptFormatsMateAndUnknownScores() {
        let mateForPlayer = LLMCoachingPrompt(score: .mate(2), bestMove: "h5f7", alternatives: [], playerColor: .black)
        XCTAssertTrue(mateForPlayer.promptString.contains("Black to move"))
        XCTAssertTrue(mateForPlayer.promptString.contains("mate in 2"))
        XCTAssertFalse(mateForPlayer.promptString.contains("alternatives:"))

        let mateForOpponent = LLMCoachingPrompt(score: .mate(-4), bestMove: "a2a3", alternatives: [], playerColor: .white)
        XCTAssertTrue(mateForOpponent.promptString.contains("mate in 4 (for opponent)"))

        let boundScore = LLMCoachingPrompt(score: .upperBound(15), bestMove: "e2e4", alternatives: [(move: "e7e5", score: .lowerBound(-20))], playerColor: .white)
        XCTAssertTrue(boundScore.promptString.contains("advantage: unknown"))
        XCTAssertTrue(boundScore.promptString.contains("e7e5 (?)"))
    }

    func testLLMErrorDescriptions_areUserReadable() {
        XCTAssertEqual(LLMError.modelNotLoaded.errorDescription, "Model not loaded")
        XCTAssertEqual(LLMError.generationFailed("bad").errorDescription, "Generation failed: bad")
        XCTAssertEqual(LLMError.modelLoadFailed("missing").errorDescription, "Model load failed: missing")
        XCTAssertEqual(LLMError.timeout.errorDescription, "Generation timed out")
        XCTAssertEqual(LLMError.cancelled.errorDescription, "Generation cancelled")
        XCTAssertEqual(LLMError.notSupported.errorDescription, "LLM inference not supported on this device")
    }

    func testEngineErrorDescriptions_areUserReadable() {
        XCTAssertEqual(EngineError.notAvailable.errorDescription, "Engine binary not found")
        XCTAssertEqual(EngineError.initializationFailed("uci").errorDescription, "Engine init failed: uci")
        XCTAssertEqual(EngineError.processError("pipe").errorDescription, "Engine process error: pipe")
        XCTAssertEqual(EngineError.timeout.errorDescription, "Engine analysis timed out")
    }

    func testLc0AdapterDocumentsUnavailableStubBehavior() async {
        let adapter = Lc0Adapter()
        XCTAssertEqual(adapter.displayName, "Lc0 (Leela Chess Zero)")
        XCTAssertFalse(adapter.isAvailable)
        XCTAssertNil(adapter.lastBestMove)

        do {
            try await adapter.initialize()
            XCTFail("Lc0 adapter is a documented unavailable stub until lc0-http is integrated")
        } catch EngineError.notAvailable {
            // expected
        } catch {
            XCTFail("Expected EngineError.notAvailable, got \(error)")
        }
        XCTAssertFalse(adapter.isAvailable)
    }

    func testLc0StartAnalysisReturnsEmptyPublisherAndShutdownIsSafe() {
        let adapter = Lc0Adapter()
        let exp = expectation(description: "empty lc0 publisher should not emit")
        exp.isInverted = true
        let cancellable = adapter.startAnalysis(fen: Position.startingFen, depth: 1, timeout: 0.01)
            .sink { _ in exp.fulfill() }

        adapter.stopAnalysis()
        adapter.shutdown()
        wait(for: [exp], timeout: 0.05)
        cancellable.cancel()
    }

    func testSwiftLlamaAdapterLifecycleAndNotLoadedError() async {
        let adapter = SwiftLlamaAdapter(modelPath: URL(fileURLWithPath: "/tmp/nonexistent-unit-model.gguf"))
        XCTAssertFalse(adapter.isReady)

        do {
            _ = try await adapter.generateCoachingText(from: LLMCoachingPrompt(score: .cp(0), bestMove: "e2e4", alternatives: [], playerColor: .white))
            XCTFail("Expected modelNotLoaded")
        } catch LLMError.modelNotLoaded {
            // expected
        } catch {
            XCTFail("Expected modelNotLoaded, got \(error)")
        }

        try? await adapter.loadModel()
        XCTAssertTrue(adapter.isReady)
        await adapter.unloadModel()
        XCTAssertFalse(adapter.isReady)
    }

    func testStockfishAdapterParsesBestMoveAndEngineLinesFromBridgeOutput() {
        let adapter = StockfishAdapter()
        var received: [EngineLine] = []
        let lineExpectation = expectation(description: "engine line emitted")

        let cancellable = adapter.startAnalysis(fen: "startpos", depth: 8, timeout: nil)
            .sink { line in
                received.append(line)
                lineExpectation.fulfill()
            }

        adapter.test_handleEngineOutput("stockfish:ready")
        adapter.test_handleEngineOutput("uciok")
        adapter.test_handleEngineOutput("readyok")
        adapter.test_handleEngineOutput("info depth 8 score cp 34 pv e2e4 e7e5")
        adapter.test_handleEngineOutput("bestmove e2e4")

        wait(for: [lineExpectation], timeout: 1)
        XCTAssertTrue(adapter.isAvailable)
        XCTAssertEqual(adapter.lastBestMove, "e2e4")
        XCTAssertEqual(received.first?.depth, 8)
        XCTAssertEqual(received.first?.score, .cp(34))
        XCTAssertEqual(received.first?.moves, ["e2e4", "e7e5"])

        cancellable.cancel()
        adapter.stopAnalysis()
        adapter.shutdown()
    }

    func testUCIParserHandlesBoundMarkerAfterCpScore() {
        XCTAssertEqual(
            UCIParser.parseInfoLine("info depth 12 score cp 15 upperbound pv e2e4")?.score,
            .upperBound(15)
        )
        XCTAssertEqual(
            UCIParser.parseInfoLine("info depth 12 score cp -9 lowerbound pv e2e4")?.score,
            .lowerBound(-9)
        )
    }

    func testUCIParserRejectsMalformedScoreTokens() {
        XCTAssertNil(UCIParser.parseInfoLine("info depth 12 score cp not-a-number pv e2e4"))
        XCTAssertNil(UCIParser.parseInfoLine("info depth 12 score mate nope pv e2e4"))
        XCTAssertNil(UCIParser.parseInfoLine("info depth 12 score lowerbound pv e2e4"))
    }
}
