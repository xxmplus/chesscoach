import Foundation
import Combine

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var estimatedRating: Int = 1000
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var totalPuzzlesSolved: Int = 0
    @Published var totalLessonsCompleted: Int = 0
    @Published var ratingHistory: [(date: Date, rating: Int)] = []
    @Published var topWeaknesses: [(theme: String, count: Int)] = []

    private let tracker = ProgressTracker()
    private var cancellables = Set<AnyCancellable>()

    init() {
        load()
    }

    func load() {
        estimatedRating = tracker.estimatedRating
        currentStreak = tracker.currentStreak
        bestStreak = tracker.bestStreak
        totalPuzzlesSolved = tracker.totalPuzzlesSolved
        totalLessonsCompleted = tracker.totalLessonsCompleted
        ratingHistory = DatabaseManager.shared.getRatingHistory()
        topWeaknesses = tracker.topWeaknesses()
    }

    func recordActivity() {
        tracker.recordDailyActivity()
        load()
    }
}
