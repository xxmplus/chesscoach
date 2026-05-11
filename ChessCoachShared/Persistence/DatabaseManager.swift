import Foundation
import SQLite

// MARK: - DatabaseManager

public final class DatabaseManager {
    public static let shared = DatabaseManager()

    private var db: Connection?

    // Tables
    private let lessons = Table("lessons")
    private let puzzles = Table("puzzles")
    private let sessions = Table("sessions")
    private let ratingHistory = Table("rating_history")

    // Lesson columns
    private let lessonId = SQLite.Expression<String>("id")
    private let lessonPhase = SQLite.Expression<String>("phase")
    private let lessonTitle = SQLite.Expression<String>("title")
    private let lessonDifficulty = SQLite.Expression<Int>("difficulty")
    private let lessonStars = SQLite.Expression<Int>("stars")
    private let lessonStatus = SQLite.Expression<String>("status")

    // Puzzle columns
    private let puzzleId = SQLite.Expression<String>("id")
    private let puzzleRating = SQLite.Expression<Int>("rating")
    private let puzzleSolved = SQLite.Expression<Bool>("solved")
    private let puzzleAttempts = SQLite.Expression<Int>("attempts")
    private let puzzleHintsUsed = SQLite.Expression<Int>("hints_used")

    // Session columns
    private let sessionId = SQLite.Expression<String>("id")
    private let sessionDate = SQLite.Expression<Date>("date")
    private let sessionType = SQLite.Expression<String>("type")
    private let sessionResult = SQLite.Expression<String>("result")

    // Rating history columns
    private let ratingDate = SQLite.Expression<Date>("date")
    private let ratingValue = SQLite.Expression<Int>("rating")

    private init() {
        setup()
    }

    private func setup() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            db = try Connection("\(path)/chesscoach.sqlite3")

            try db?.run(lessons.create(ifNotExists: true) { t in
                t.column(lessonId, primaryKey: true)
                t.column(lessonPhase)
                t.column(lessonTitle)
                t.column(lessonDifficulty)
                t.column(lessonStars)
                t.column(lessonStatus)
            })

            try db?.run(puzzles.create(ifNotExists: true) { t in
                t.column(puzzleId, primaryKey: true)
                t.column(puzzleRating)
                t.column(puzzleSolved)
                t.column(puzzleAttempts)
                t.column(puzzleHintsUsed)
            })

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
            print("DatabaseManager init error: \(error)")
        }
    }

    // MARK: - Lessons

    public func saveLessonProgress(id: String, phase: String, title: String, difficulty: Int, stars: Int, status: String) {
        do {
            let insert = lessons.insert(or: .replace,
                lessonId <- id,
                lessonPhase <- phase,
                lessonTitle <- title,
                lessonDifficulty <- difficulty,
                lessonStars <- stars,
                lessonStatus <- status
            )
            try db?.run(insert)
        } catch {
            print("saveLessonProgress error: \(error)")
        }
    }

    public func getLessonProgress(id: String) -> (stars: Int, status: String)? {
        do {
            let query = lessons.filter(lessonId == id)
            if let row = try db?.pluck(query) {
                return (row[lessonStars], row[lessonStatus])
            }
        } catch {
            print("getLessonProgress error: \(error)")
        }
        return nil
    }

    public func getAllLessonProgress() -> [String: (stars: Int, status: String)] {
        var result: [String: (stars: Int, status: String)] = [:]
        do {
            if let rows = try db?.prepare(lessons) {
                for row in rows {
                    result[row[lessonId]] = (row[lessonStars], row[lessonStatus])
                }
            }
        } catch {
            print("getAllLessonProgress error: \(error)")
        }
        return result
    }

    // MARK: - Puzzles

    public func savePuzzleResult(id: String, rating: Int, solved: Bool, hintsUsed: Int) {
        do {
            let attempts = puzzleAttempts + 1
            let insert = puzzles.insert(or: .replace,
                puzzleId <- id,
                puzzleRating <- rating,
                puzzleSolved <- solved,
                puzzleAttempts <- attempts,
                puzzleHintsUsed <- hintsUsed
            )
            try db?.run(insert)
        } catch {
            print("savePuzzleResult error: \(error)")
        }
    }

    public func getPuzzleStats(id: String) -> (solved: Bool, attempts: Int, hintsUsed: Int)? {
        do {
            let query = puzzles.filter(puzzleId == id)
            if let row = try db?.pluck(query) {
                return (row[puzzleSolved], row[puzzleAttempts], row[puzzleHintsUsed])
            }
        } catch {
            print("getPuzzleStats error: \(error)")
        }
        return nil
    }

    // MARK: - Sessions

    public func logSession(type: String, result: String) {
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

    // MARK: - Rating History

    public func recordRating(_ value: Int) {
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

    public func getRatingHistory() -> [(date: Date, rating: Int)] {
        var result: [(Date, Int)] = []
        do {
            if let rows = try db?.prepare(ratingHistory.order(ratingDate.asc)) {
                for row in rows {
                    result.append((row[ratingDate], row[ratingValue]))
                }
            }
        } catch {
            print("getRatingHistory error: \(error)")
        }
        return result
    }

    public func currentEstimatedRating() -> Int? {
        let history = getRatingHistory()
        return history.last?.rating
    }
}
