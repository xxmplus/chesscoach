import Foundation
import Combine

// MARK: - LearnViewModel

@MainActor
final class LearnViewModel: ObservableObject {
    @Published var lessons: [Lesson] = []
    @Published var progressMap: [String: LessonProgress] = [:]
    @Published var selectedPhase: Lesson.Phase?

    private let loader = ContentLoader.shared
    private let db = DatabaseManager.shared

    init() {
        load()
    }

    func load() {
        lessons = loader.loadLessons()
        let stored = db.getAllLessonProgress()
        progressMap = stored.mapValues { (stars: $0.stars, status: Lesson.Status(rawValue: $0.status) ?? .notStarted) }
    }

    func lessons(for phase: Lesson.Phase?) -> [Lesson] {
        if let phase = phase {
            return lessons.filter { $0.phase == phase }
        }
        return lessons
    }

    func progress(for lesson: Lesson) -> LessonProgress {
        if let p = progressMap[lesson.id] {
            return p
        }
        return LessonProgress(lessonId: lesson.id, stars: 0, status: .notStarted)
    }

    func markStarted(_ lesson: Lesson) {
        var p = progress(for: lesson)
        p.status = .inProgress
        progressMap[lesson.id] = p
        db.saveLessonProgress(
            id: lesson.id, phase: lesson.phase.rawValue,
            title: lesson.title, difficulty: lesson.difficulty,
            stars: p.stars, status: p.status.rawValue
        )
    }

    func markCompleted(_ lesson: Lesson, stars: Int) {
        var p = progress(for: lesson)
        p.stars = max(p.stars, stars)
        p.status = .completed
        progressMap[lesson.id] = p
        db.saveLessonProgress(
            id: lesson.id, phase: lesson.phase.rawValue,
            title: lesson.title, difficulty: lesson.difficulty,
            stars: p.stars, status: p.status.rawValue
        )
    }

    var completedCount: Int {
        progressMap.values.filter { $0.status == .completed }.count
    }

    var totalStars: Int {
        progressMap.values.reduce(0) { $0 + $1.stars }
    }

    var maxPossibleStars: Int {
        lessons.count * 3
    }
}
