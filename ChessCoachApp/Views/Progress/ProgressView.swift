import SwiftUI

struct ProgressView: View {
    @StateObject private var vm = ProgressViewModel()

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Rating badge
                    VStack(spacing: 12) {
                        RatingBadge(rating: vm.estimatedRating, size: 120)
                        Text("Estimated Elo")
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                        Text(ratingLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.primary)
                    }
                    .padding(.top, 8)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Puzzles Solved", value: "\(vm.totalPuzzlesSolved)", icon: "puzzlepiece.fill")
                        StatCard(title: "Lessons Done", value: "\(vm.totalLessonsCompleted)", icon: "book.fill")
                        StatCard(title: "Day Streak", value: "\(vm.currentStreak)", icon: "flame.fill")
                        StatCard(title: "Best Streak", value: "\(vm.bestStreak)", icon: "crown.fill")
                    }
                    .padding(.horizontal)

                    // Weaknesses
                    if !vm.topWeaknesses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Areas to Improve")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)

                            ForEach(vm.topWeaknesses, id: \.theme) { item in
                                HStack {
                                    Text(item.theme)
                                        .font(.subheadline)
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Text("\(item.count) mistakes")
                                        .font(.caption)
                                        .foregroundColor(theme.accent)
                                }
                                .padding(10)
                                .background(theme.surface)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Rating history chart placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rating History")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)

                        if vm.ratingHistory.isEmpty {
                            Text("Complete puzzles and lessons to see your progress")
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                                .padding(.vertical, 20)
                        } else {
                            SimpleRatingChart(history: vm.ratingHistory)
                                .frame(height: 120)
                        }
                    }
                    .padding(.horizontal)
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .background(theme.background)
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var ratingLabel: String {
        switch vm.estimatedRating {
        case ..<1000: return "Beginner"
        case 1000..<1200: return "Novice"
        case 1200..<1400: return "Intermediate"
        case 1400..<1600: return "Club Player"
        case 1600..<1800: return "Strong Club"
        default: return "Candidate Master"
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(theme.primary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(theme.surface)
        .cornerRadius(12)
    }
}

// MARK: - SimpleRatingChart

struct SimpleRatingChart: View {
    let history: [(date: Date, rating: Int)]

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        GeometryReader { geo in
            let minR = history.map(\.rating).min() ?? 1000
            let maxR = history.map(\.rating).max() ?? 1000
            let range = max(1, maxR - minR)
            let points = history.enumerated().map { index, item -> CGPoint in
                let x = geo.size.width * CGFloat(index) / CGFloat(max(1, history.count - 1))
                let y = geo.size.height * (1 - CGFloat(item.rating - minR) / CGFloat(range))
                return CGPoint(x: x, y: y)
            }

            Path { path in
                guard !points.isEmpty else { return }
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(theme.primary, lineWidth: 2)
        }
    }
}
