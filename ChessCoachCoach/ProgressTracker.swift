import Foundation
import Combine
import SQLite

// MARK: - ProgressTracker

/// Tracks user rating, session history, and weakness areas.
/// Owns its own SQLite database to avoid cross-framework coupling.
public final class ProgressTracker: ObservableObject {
    @Published public private(set) var estimatedRating: Int = 1000
    @Published public private(set) var currentStreak: Int = 0
    @Published public private(set) var bestStreak: Int = 0
    @Published public private(set) var totalPuzzlesSolved: Int = 0
    @Published public private(set) var totalLessonsCompleted: Int = 0
    @Published public private(set) var weaknessAreas: [String: Int] = [:] // theme → fail count

    private var db: Connection?

    // Tables
    private let sessions = Table("sessions")
    private let ratingHistory = Table("rating_history")

    // Columns
    private let sessionId = SQLite.Expression<String>("id")
    private let sessionDate = SQLite.Expression<Date>("date")
    private let sessionType = SQLite.Expression<String>("type")
    private let sessionResult = SQLite.Expression<String>("result")
    private let ratingDate = SQLite.Expression<Date>("date")
    private let ratingValue = SQLite.Expression<Int>("rating")

    public init() {
        setup()
        load()
    }

    private func setup() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(path)/chesscoach.sqlite3")

            try db?.run(sessions.create(ifNotExists: true) { t in
                t.column(sessionId, primaryKey: true)
                t.column(sessionDate)
                t.column(sessionType)
                t.column(sessionResult)
            })

            try db?.run(ratingHistory.create(ifNotExists: true) { t in
                t.column(ratingDate)
                t.column(ratingValue)
            })
        } catch {
            print("ProgressTracker init error: \(error)")
        }
    }

    public func load() {
        estimatedRating = currentEstimatedRating() ?? 1000
    }

    // MARK: - Puzzle Events

    public func puzzleSolved(rating: Int, themes: [String], hintsUsed: Int) {
        totalPuzzlesSolved += 1

        // Glicko-style approximation
        let delta = max(5, min(32, Int(Double(rating - estimatedRating) / 30) + 8))
        estimatedRating += delta

        for theme in themes {
            weaknessAreas[theme, default: 0] += hintsUsed > 0 ? 1 : 0
        }

        recordRating(estimatedRating)
        logSession(type: "puzzle", result: "solved")
    }

    public func puzzleFailed(rating: Int, themes: [String]) {
        estimatedRating += -8
        for theme in themes {
            weaknessAreas[theme, default: 0] += 1
        }
        recordRating(estimatedRating)
        logSession(type: "puzzle", result: "failed")
    }

    // MARK: - Lesson Events

    public func lessonStarted(id: String) {
        logSession(type: "lesson", result: "started")
    }

    public func lessonCompleted(id: String, stars: Int) {
        totalLessonsCompleted += 1
        let bonus = stars * 4
        estimatedRating += bonus
        recordRating(estimatedRating)
        logSession(type: "lesson", result: "completed(\(stars)stars)")
    }

    // MARK: - Streak

    public func recordDailyActivity() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let lastSessionDate = UserDefaults.standard.object(forKey: "last_activity_date") as? Date
        if let last = lastSessionDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            if lastDay == yesterday {
                currentStreak += 1
            } else if lastDay != today {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        bestStreak = max(bestStreak, currentStreak)
        UserDefaults.standard.set(today, forKey: "last_activity_date")
    }

    // MARK: - Weaknesses

    public func topWeaknesses(limit: Int = 5) -> [(theme: String, count: Int)] {
        weaknessAreas
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Private DB helpers

    private func logSession(type: String, result: String) {
        do {
            let id = UUID().uuidString
            let insert = sessions.insert(
                sessionId <- id,
                sessionDate <- Date(),
                sessionType <- type,
                sessionResult <- result
            )
            try db?.run(insert)
        } catch {
            print("logSession error: \(error)")
        }
    }

    private func recordRating(_ value: Int) {
        do {
            let insert = ratingHistory.insert(
                ratingDate <- Date(),
                ratingValue <- value
            )
            try db?.run(insert)
        } catch {
            print("recordRating error: \(error)")
        }
    }

    private func currentEstimatedRating() -> Int? {
        var result: Int?
        do {
            if let row = try db?.pluck(ratingHistory.order(ratingDate.desc).limit(1)) {
                result = row[ratingValue]
            }
        } catch {
            print("currentEstimatedRating error: \(error)")
        }
        return result
    }
}
