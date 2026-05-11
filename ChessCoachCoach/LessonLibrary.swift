import Foundation

// MARK: - Lesson

public struct Lesson: Identifiable, Codable {
    public let id: String
    public let phase: Phase
    public let title: String
    public let difficulty: Int      // Elo estimate
    public let body: String         // HTML lesson content
    public let positions: [LessonPosition]
    public let starsThresholds: StarsThresholds

    public struct LessonPosition: Codable {
        public let fen: String
        public let description: String
        public let moves: [String]?

        public init(fen: String, description: String, moves: [String]? = nil) {
            self.fen = fen
            self.description = description
            self.moves = moves
        }
    }

    public struct StarsThresholds: Codable {
        public let one: Int   // attempts to earn 1 star
        public let two: Int   // attempts to earn 2 stars
        public let three: Int // attempts to earn 3 stars
    }

    public enum Phase: String, Codable, CaseIterable {
        case opening = "opening"
        case middlegame = "middlegame"
        case endgame = "endgame"

        public var displayName: String {
            switch self {
            case .opening:   return "Opening"
            case .middlegame: return "Middlegame"
            case .endgame:   return "Endgame"
            }
        }

        public var icon: String {
            switch self {
            case .opening:   return "book.fill"
            case .middlegame: return "figure.chess"
            case .endgame:   return "circle.hexagongrid.fill"
            }
        }
    }
}

// MARK: - LessonProgress

public struct LessonProgress {
    public let lessonId: String
    public var stars: Int       // 0-3
    public var status: Status

    public enum Status: String {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed = "completed"
    }

    public init(lessonId: String, stars: Int, status: Status) {
        self.lessonId = lessonId
        self.stars = stars
        self.status = status
    }
}

// MARK: - Hashable

extension Lesson: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    public static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id
    }
}

extension LessonProgress: Hashable {}
extension Lesson.Phase: Hashable {}
extension Lesson.LessonPosition: Hashable {}
extension Lesson.StarsThresholds: Hashable {}
