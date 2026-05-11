import SwiftUI

struct LearnView: View {
    @StateObject private var vm = LearnViewModel()
    @State private var selectedLesson: Lesson?

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress header
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Curriculum")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(theme.textPrimary)
                            Text("\(vm.completedCount)/\(vm.lessons.count) lessons completed")
                                .font(.subheadline)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        StarsBadge(current: vm.totalStars, max: vm.maxPossibleStars)
                    }
                    .padding(.horizontal)

                    // Phase selector
                    HStack(spacing: 12) {
                        ForEach(Lesson.Phase.allCases, id: \.self) { phase in
                            PhaseButton(
                                phase: phase,
                                isSelected: vm.selectedPhase == phase,
                                lessonCount: vm.lessons(for: phase).count,
                                completedCount: vm.lessons(for: phase).filter { vm.progress(for: $0).status == .completed }.count
                            ) {
                                if vm.selectedPhase == phase {
                                    vm.selectedPhase = nil
                                } else {
                                    vm.selectedPhase = phase
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Lesson list
                    LazyVStack(spacing: 12) {
                        ForEach(vm.lessons(for: vm.selectedPhase)) { lesson in
                            LessonRowView(
                                lesson: lesson,
                                progress: vm.progress(for: lesson)
                            )
                            .onTapGesture {
                                selectedLesson = lesson
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(theme.background)
            .navigationDestination(item: $selectedLesson) { lesson in
                LessonDetailView(lesson: lesson, vm: vm)
            }
        }
    }
}

// MARK: - StarsBadge

struct StarsBadge: View {
    let current: Int
    let max: Int

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .foregroundColor(ChessTheme.midnightStudy.primary)
                Text("\(current)/\(max)")
                    .font(.caption.bold())
                    .foregroundColor(ChessTheme.midnightStudy.textMuted)
            }
        }
        .padding(8)
        .background(ChessTheme.midnightStudy.surface)
        .cornerRadius(8)
    }
}

// MARK: - PhaseButton

struct PhaseButton: View {
    let phase: Lesson.Phase
    let isSelected: Bool
    let lessonCount: Int
    let completedCount: Int
    let action: () -> Void

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: phase.icon)
                    .font(.title2)
                Text(phase.displayName)
                    .font(.caption.bold())
                Text("\(completedCount)/\(lessonCount)")
                    .font(.caption2)
                    .foregroundColor(isSelected ? theme.primary : theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? theme.primary.opacity(0.15) : theme.surface)
            .foregroundColor(isSelected ? theme.primary : theme.textMuted)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.primary : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - LessonRowView

struct LessonRowView: View {
    let lesson: Lesson
    let progress: LessonProgress

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        HStack(spacing: 14) {
            // Phase icon
            Image(systemName: lesson.phase.icon)
                .font(.title2)
                .foregroundColor(theme.primary)
                .frame(width: 40, height: 40)
                .background(theme.surfaceLight)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                HStack(spacing: 8) {
                    DifficultyBadge(difficulty: lesson.difficulty)
                    Text("\(lesson.difficulty)")
                        .font(.caption2)
                        .foregroundColor(theme.textMuted)
                }
            }

            Spacer()

            // Stars
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < progress.stars ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(i < progress.stars ? theme.primary : theme.textMuted.opacity(0.3))
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(theme.textMuted)
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(12)
    }
}

// MARK: - DifficultyBadge

struct DifficultyBadge: View {
    let difficulty: Int

    private var color: Color {
        switch difficulty {
        case ..<900:  return .green
        case 900..<1100: return .yellow
        case 1100..<1400: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text(eloLabel)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }

    private var eloLabel: String {
        if difficulty < 1200 { return "Beginner" }
        if difficulty < 1400 { return "Intermediate" }
        if difficulty < 1600 { return "Advanced" }
        return "Expert"
    }
}
