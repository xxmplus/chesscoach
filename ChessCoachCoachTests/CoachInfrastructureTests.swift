import XCTest
@testable import ChessCoachCoach
@testable import ChessCoachEngine
@testable import ChessCoachShared

final class CoachInfrastructureTests: XCTestCase {

    func testProgressTrackerPuzzleSolvedRaisesRatingAndTracksHintWeaknesses() {
        let tracker = ProgressTracker()
        let startingRating = tracker.estimatedRating

        tracker.puzzleSolved(rating: startingRating + 300, themes: ["fork", "pin"], hintsUsed: 1)

        XCTAssertEqual(tracker.totalPuzzlesSolved, 1)
        XCTAssertGreaterThan(tracker.estimatedRating, startingRating)
        XCTAssertEqual(tracker.weaknessAreas["fork"], 1)
        XCTAssertEqual(tracker.weaknessAreas["pin"], 1)
        XCTAssertTrue(["fork", "pin"].contains(tracker.topWeaknesses(limit: 1).first?.theme))
    }

    func testProgressTrackerPuzzleSolvedWithoutHintsDoesNotAddWeaknessCount() {
        let tracker = ProgressTracker()
        tracker.puzzleSolved(rating: tracker.estimatedRating, themes: ["skewer"], hintsUsed: 0)

        XCTAssertEqual(tracker.totalPuzzlesSolved, 1)
        XCTAssertEqual(tracker.weaknessAreas["skewer"], 0)
    }

    func testProgressTrackerPuzzleFailedLowersRatingAndRecordsWeaknesses() {
        let tracker = ProgressTracker()
        let startingRating = tracker.estimatedRating

        tracker.puzzleFailed(rating: 900, themes: ["back-rank", "back-rank", "fork"])

        XCTAssertEqual(tracker.estimatedRating, startingRating - 8)
        XCTAssertEqual(tracker.weaknessAreas["back-rank"], 2)
        XCTAssertEqual(tracker.weaknessAreas["fork"], 1)
        XCTAssertEqual(tracker.topWeaknesses(limit: 1).first?.count, 2)
    }

    func testProgressTrackerLessonCompletionAddsStarsBonus() {
        let tracker = ProgressTracker()
        let startingRating = tracker.estimatedRating

        tracker.lessonStarted(id: "lesson-start")
        tracker.lessonCompleted(id: "lesson-complete", stars: 3)

        XCTAssertEqual(tracker.totalLessonsCompleted, 1)
        XCTAssertEqual(tracker.estimatedRating, startingRating + 12)
    }

    func testProgressTrackerDailyActivityStartsAndMaintainsStreakForSameDay() {
        UserDefaults.standard.removeObject(forKey: "last_activity_date")
        let tracker = ProgressTracker()

        tracker.recordDailyActivity()
        tracker.recordDailyActivity()

        XCTAssertEqual(tracker.currentStreak, 1)
        XCTAssertEqual(tracker.bestStreak, 1)
    }

    func testProgressTrackerDailyActivityContinuesYesterdayStreak() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        UserDefaults.standard.set(yesterday, forKey: "last_activity_date")
        let tracker = ProgressTracker()

        tracker.recordDailyActivity()

        XCTAssertEqual(tracker.currentStreak, 1, "A fresh tracker increments from its zero in-memory streak when yesterday was recorded")
        XCTAssertEqual(tracker.bestStreak, 1)
    }

    func testLLMCoachEngineLifecycleDelegatesToService() async throws {
        let service = FakeLLMService(response: "Use your pieces together. This keeps the attack simple.")
        let engine = LLMCoachEngine(llmService: service)
        XCTAssertFalse(engine.isReady)

        try await engine.start()
        XCTAssertTrue(engine.isReady)
        let loadCount = await service.loadCount
        XCTAssertEqual(loadCount, 1)

        await engine.stop()
        XCTAssertFalse(engine.isReady)
        let unloadCount = await service.unloadCount
        XCTAssertEqual(unloadCount, 1)
    }

    func testLLMCoachEngineGeneratesVerdictPlusLLMExplanationWithStructuredPrompt() async {
        let service = FakeLLMService(response: "Developing the knight fights for the center. It also prepares castling.")
        let engine = LLMCoachEngine(llmService: service)
        let move = Move(from: Square(file: 6, rank: 0), to: Square(file: 5, rank: 2))
        let position = Position()
        let eval = EngineLine(depth: 12, score: .cp(120), moves: ["g1f3", "d2d4"], pv: "g1f3 d7d5")
        let candidate = EngineLine(depth: 12, score: .cp(90), moves: ["d2d4"], pv: "d2d4")

        let messages = await engine.generateMoveExplanation(
            move: move,
            position: position,
            engineEval: eval,
            engineCandidates: [candidate],
            bestMove: move
        )

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].category, .moveExplanation)
        XCTAssertTrue(messages[0].content.contains("great move") || messages[0].content.contains("great"))
        XCTAssertEqual(messages[1].content, service.response)
        let prompt = await service.prompts.last
        XCTAssertEqual(prompt?.bestMove, "g1f3")
        XCTAssertEqual(prompt?.alternatives.first?.move, "d2d4")
        XCTAssertEqual(prompt?.playerColor, .white)
    }

    func testLLMCoachEngineFallsBackToVerdictWhenGenerationFails() async {
        let service = FakeLLMService(error: LLMError.generationFailed("unit"))
        let engine = LLMCoachEngine(llmService: service)
        let messages = await engine.generateMoveExplanation(
            move: Move(from: Square(file: 4, rank: 1), to: Square(file: 4, rank: 3)),
            position: Position(),
            engineEval: EngineLine(depth: 1, score: .cp(-100), moves: ["e2e4"], pv: "e2e4"),
            engineCandidates: [],
            bestMove: nil
        )

        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].content.lowercased().contains("blunder"))
    }

    @MainActor
    func testCoachManagerTemplateModeIsReadyAndGeneratesMessagesWithoutLLM() async {
        let manager = CoachManager()
        manager.useLLM = false

        await manager.initialize()
        let messages = await manager.generateMoveExplanation(
            move: Move(from: Square(file: 4, rank: 1), to: Square(file: 4, rank: 3)),
            position: Position(),
            engineEval: EngineLine(depth: 5, score: .cp(50), moves: ["e2e4"], pv: "e2e4"),
            engineCandidates: [],
            bestMove: nil
        )

        XCTAssertTrue(manager.isReady)
        XCTAssertFalse(manager.isLLMLoading)
        XCTAssertFalse(manager.isLLMAvailable)
        XCTAssertFalse(messages.isEmpty)
        XCTAssertEqual(manager.modelDisplayName, ModelConfig.deepseekR1_Qwen_1_5B.displayName)
        XCTAssertTrue(manager.deviceTierDescription.contains("DeepSeek-R1 recommended"))
    }

    func testLessonValueTypesAndPhaseMetadata() throws {
        let position = Lesson.LessonPosition(fen: Position.startingFen, description: "Start", moves: ["e2e4"])
        let thresholds = Lesson.StarsThresholds(one: 5, two: 3, three: 1)
        let lesson = Lesson(id: "l1", phase: .opening, title: "Opening", difficulty: 800, body: "Body", positions: [position], starsThresholds: thresholds)
        let sameID = Lesson(id: "l1", phase: .endgame, title: "Other", difficulty: 1200, body: "Other", positions: [], starsThresholds: thresholds)

        XCTAssertEqual(lesson, sameID, "Lesson identity is intentionally based on id only")
        XCTAssertEqual(Lesson.Phase.opening.displayName, "Opening")
        XCTAssertEqual(Lesson.Phase.middlegame.displayName, "Middlegame")
        XCTAssertEqual(Lesson.Phase.endgame.displayName, "Endgame")
        XCTAssertEqual(Lesson.Phase.opening.icon, "book.fill")
        XCTAssertEqual(Lesson.Phase.middlegame.icon, "figure.chess")
        XCTAssertEqual(Lesson.Phase.endgame.icon, "circle.hexagongrid.fill")

        let encoded = try JSONEncoder().encode(lesson)
        let decoded = try JSONDecoder().decode(Lesson.self, from: encoded)
        XCTAssertEqual(decoded.id, lesson.id)
        XCTAssertEqual(decoded.positions.first?.moves, ["e2e4"])
    }

    func testLessonProgressStoresStatusAndStars() {
        var progress = LessonProgress(lessonId: "lesson", stars: 1, status: .inProgress)
        XCTAssertEqual(progress.lessonId, "lesson")
        XCTAssertEqual(progress.stars, 1)
        XCTAssertEqual(progress.status.rawValue, "in_progress")

        progress.stars = 3
        progress.status = .completed
        XCTAssertEqual(progress.stars, 3)
        XCTAssertEqual(progress.status, .completed)
        XCTAssertEqual(LessonProgress.Status.notStarted.rawValue, "not_started")
    }

    func testCoachEngineExplainsCaptureAndAlternative() {
        let engine = CoachEngine()
        let fen = "4k3/8/8/8/8/8/4q3/4R2K w - - 0 1"
        let position = Position(fen: fen)
        let move = Move(from: Square(file: 4, rank: 0), to: Square(file: 4, rank: 1))
        let alternative = EngineLine(depth: 10, score: .cp(120), moves: ["h1g1"], pv: "h1g1")

        let messages = engine.generateMoveExplanation(
            move: move,
            position: position,
            engineEval: EngineLine(depth: 10, score: .cp(350), moves: ["e1e2"], pv: "e1e2"),
            engineCandidates: [alternative],
            bestMove: nil
        )

        XCTAssertTrue(messages.contains { $0.content.contains("captured") || $0.content.contains("gained material") })
        XCTAssertTrue(messages.contains { $0.category == .moveComparison })
        XCTAssertTrue(messages.contains { $0.category == .principle })
    }

    func testCoachMessagePriorityOrdersCriticalBeforeLow() {
        XCTAssertLessThan(CoachMessagePriority.critical, .high)
        XCTAssertLessThan(CoachMessagePriority.high, .medium)
        XCTAssertLessThan(CoachMessagePriority.medium, .low)
    }
}

private actor FakeLLMService: LLMService {
    let response: String
    let error: Error?
    private(set) var prompts: [LLMCoachingPrompt] = []
    private(set) var loadCount = 0
    private(set) var unloadCount = 0
    nonisolated private let readiness = ReadinessBox()

    nonisolated var isReady: Bool { readiness.value }

    init(response: String = "ok", error: Error? = nil) {
        self.response = response
        self.error = error
    }

    func loadModel() async throws {
        loadCount += 1
        readiness.value = true
    }

    func unloadModel() async {
        unloadCount += 1
        readiness.value = false
    }

    func generateCoachingText(from prompt: LLMCoachingPrompt) async throws -> String {
        prompts.append(prompt)
        if let error { throw error }
        return response
    }
}

private final class ReadinessBox: @unchecked Sendable {
    var value = false
}
