import SwiftUI

struct PuzzlesView: View {
    @EnvironmentObject private var engineManager: EngineManager
    @StateObject private var vm = PuzzleViewModel()
    @State private var showHint = false

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Puzzle header
                    if let puzzle = vm.currentPuzzle {
                        VStack(spacing: 8) {
                            Text("Puzzle #\(puzzle.id)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textMuted)
                            HStack(spacing: 8) {
                                DifficultyBadge(difficulty: puzzle.difficulty * 100)
                                ForEach(puzzle.themes, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .foregroundColor(theme.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(theme.primary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }

                        // Board
                        ChessBoardView(
                            position: $vm.position,
                            interactive: true,
                            engineLines: vm.engineLines
                        ) { move in
                            vm.submitMove(move.from.description + move.to.description)
                        }
                        .frame(maxWidth: 380)
                        .frame(height: 380)
                        .padding()
                        .background(theme.surface)
                        .cornerRadius(12)

                        // Feedback
                        if let message = vm.feedbackMessage {
                            FeedbackBanner(message: message, type: vm.feedbackType ?? .correct)
                        }

                        // Hint
                        if let hint = vm.currentHint {
                            HintBanner(hint: hint)
                        }

                        // Hint button
                        HStack(spacing: 16) {
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

                        // Next puzzle button
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
                    } else {
                        Text("Loading puzzles...")
                            .foregroundColor(theme.textMuted)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(theme.background)
            .navigationTitle("Puzzles")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - FeedbackBanner

struct FeedbackBanner: View {
    let message: String
    let type: PuzzlesView.FeedbackType

    private var color: Color {
        switch type {
        case .correct: return ChessTheme.midnightStudy.secondary
        case .wrong:   return ChessTheme.midnightStudy.accent
        case .hint:    return ChessTheme.midnightStudy.primary
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

    private var iconName: String {
        switch type {
        case .correct: return "checkmark.circle.fill"
        case .wrong:   return "xmark.circle.fill"
        case .hint:    return "lightbulb.fill"
        }
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
