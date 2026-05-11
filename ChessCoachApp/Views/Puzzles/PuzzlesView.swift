import SwiftUI
import ChessCoachShared
import ChessCoachEngine
import ChessCoachCoach

struct PuzzlesView: View {
    @EnvironmentObject private var engineManager: EngineManager
    @StateObject private var vm = PuzzleViewModel()
    @State private var showHint = false

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        NavigationStack {
            puzzleScrollContent
                .background(theme.background)
                .navigationTitle("Puzzles")
                .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var puzzleScrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                boardSection
                feedbackSection
                hintSection
                buttonRow
                nextSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        if let puzzle = vm.currentPuzzle {
            VStack(spacing: 8) {
                Text("Puzzle #\(puzzle.id)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textMuted)

                HStack(spacing: 8) {
                    DifficultyBadge(difficulty: puzzle.rating)
                    ForEach(puzzle.themes, id: \.self) { tag in
                        tagView(tag)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(.caption2)
            .foregroundColor(theme.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.primary.opacity(0.1))
            .cornerRadius(4)
    }

    @ViewBuilder
    private var boardSection: some View {
        let binding = makeBoardBinding()
        ChessBoardView(
            position: binding,
            interactive: true,
            engineLines: vm.engineLines,
            onMove: { move in
                let uci = move.from.description + move.to.description
                vm.submitMove(uci)
            }
        )
        .frame(maxWidth: 380)
        .frame(height: 380)
        .padding()
        .background(theme.surface)
        .cornerRadius(12)
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let message = vm.feedbackMessage {
            let type = resolveFeedbackType()
            FeedbackBanner(message: message, type: type)
        }
    }

    @ViewBuilder
    private var hintSection: some View {
        if let hint = vm.currentHint {
            HintBanner(hint: hint)
        }
    }

    @ViewBuilder
    private var buttonRow: some View {
        HStack(spacing: 16) {
            hintButton
            skipButton
        }
    }

    @ViewBuilder
    private var nextSection: some View {
        if vm.isSolved {
            Button {
                vm.loadNextPuzzle()
            } label: {
                Text("Next Puzzle")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.primary)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private var hintButton: some View {
        Button {
            vm.showHint()
        } label: {
            Label("Hint", systemImage: "lightbulb")
                .font(.subheadline.bold())
                .foregroundColor(theme.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.primary.opacity(0.1))
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var skipButton: some View {
        Button {
            vm.skipPuzzle()
        } label: {
            Label("Skip", systemImage: "arrow.right")
                .font(.subheadline.bold())
                .foregroundColor(theme.textMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.surfaceLight)
                .cornerRadius(8)
        }
    }

    // MARK: - Helpers

    /// Isolating the Binding<Position> into its own helper prevents Swift compiler
    /// crashes caused by complex generic type inference in view builder contexts.
    private func makeBoardBinding() -> Binding<Position> {
        $vm.position
    }

    private func resolveFeedbackType() -> PuzzleViewModel.FeedbackType {
        vm.feedbackType ?? .correct
    }
}

// MARK: - FeedbackBanner

struct FeedbackBanner: View {
    let message: String
    let type: PuzzleViewModel.FeedbackType

    private var color: Color {
        switch type {
        case .correct: return ChessTheme.midnightStudy.secondary
        case .wrong:   return ChessTheme.midnightStudy.accent
        case .hint:    return ChessTheme.midnightStudy.primary
        }
    }

    private var iconName: String {
        switch type {
        case .correct: return "checkmark.circle.fill"
        case .wrong:   return "xmark.circle.fill"
        case .hint:    return "lightbulb.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
            Text(message)
                .font(.subheadline.bold())
        }
        .foregroundColor(color)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.12))
        .cornerRadius(10)
    }
}

// MARK: - HintBanner

struct HintBanner: View {
    let hint: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(ChessTheme.midnightStudy.primary)
            Text(hint)
                .font(.subheadline)
                .foregroundColor(ChessTheme.midnightStudy.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChessTheme.midnightStudy.surface)
        .cornerRadius(10)
    }
}
