import SwiftUI
import ChessCoachShared
import ChessCoachCoach

struct LessonDetailView: View {
    let lesson: Lesson
    @ObservedObject var vm: LearnViewModel
    @State private var position: Position
    @State private var currentPositionIndex = 0
    @State private var attempts = 0
    @Environment(\.dismiss) private var dismiss

    private let theme = ChessTheme.midnightStudy

    init(lesson: Lesson, vm: LearnViewModel) {
        self.lesson = lesson
        self.vm = vm
        _position = State(initialValue: Position(fen: lesson.positions.first?.fen ?? ""))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title & difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.title)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(theme.textPrimary)

                    HStack(spacing: 12) {
                        DifficultyBadge(difficulty: lesson.difficulty)
                        Text(lesson.phase.displayName)
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.surfaceLight)
                            .cornerRadius(4)
                    }
                }

                // Board
                ChessBoardView(position: $position, interactive: true) { move in
                    handleMove(move)
                }
                .frame(maxWidth: 400)
                .frame(height: 400)
                .padding()
                .background(theme.surface)
                .cornerRadius(12)

                // Position description
                if currentPositionIndex < lesson.positions.count {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Position \(currentPositionIndex + 1)")
                            .font(.headline)
                            .foregroundColor(theme.primary)
                        Text(lesson.positions[currentPositionIndex].description)
                            .font(.body)
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(12)
                }

                // Lesson body (HTML rendered as simple text)
                Text(lesson.body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                    .font(.body)
                    .foregroundColor(theme.textPrimary)
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(12)

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Complete") {
                    let stars = starRating
                    vm.markCompleted(lesson, stars: stars)
                    dismiss()
                }
                .foregroundColor(theme.primary)
            }
        }
        .onAppear {
            vm.markStarted(lesson)
        }
    }

    private var starRating: Int {
        if attempts >= lesson.starsThresholds.three { return 3 }
        if attempts >= lesson.starsThresholds.two   { return 2 }
        if attempts >= lesson.starsThresholds.one   { return 1 }
        return 0
    }

    private func handleMove(_ move: Move) {
        attempts += 1
        if var pos = Optional(position), currentPositionIndex < lesson.positions.count {
            let lp = lesson.positions[currentPositionIndex]
            if let guidedMoves = lp.moves, !guidedMoves.isEmpty {
                // Guided lesson: check if this move matches expected
                let expectedUci = guidedMoves[safe: currentPositionIndex]
                if move.from.description + move.to.description == expectedUci {
                    if currentPositionIndex < lesson.positions.count - 1 {
                        currentPositionIndex += 1
                        position = Position(fen: lesson.positions[currentPositionIndex].fen)
                    }
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
