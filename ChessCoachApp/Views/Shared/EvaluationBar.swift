import SwiftUI
import ChessCoachShared
import ChessCoachEngine

// MARK: - EvaluationBar

struct EvaluationBar: View {
    let line: EngineLine

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        GeometryReader { geo in
            let fraction = evaluationFraction
            let isPositive = evaluation >= 0

            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.surfaceLight)

                // Filled portion (always extends from centre)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [theme.accent, theme.surfaceLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width / 2)
                    .offset(x: 0)

                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        colors: [theme.surfaceLight, theme.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: filledWidth(in: geo.size.width))
                    .offset(x: geo.size.width / 2)

                // Centre line
                Rectangle()
                    .fill(theme.textMuted.opacity(0.5))
                    .frame(width: 1)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Score label
                Text(line.score.displayString)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .position(x: scorePosition(in: geo.size.width), y: geo.size.height / 2)
            }
        }
    }

    private var evaluation: Double {
        line.score.centipawns ?? 0
    }

    private var evaluationFraction: Double {
        let clamped = max(-1000, min(1000, evaluation))
        return (clamped + 1000) / 2000  // 0 = -1000cp, 1 = +1000cp
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        let half = totalWidth / 2
        let sign: CGFloat = evaluation >= 0 ? 1 : -1
        return half + sign * half * min(1.0, abs(evaluation) / 300.0)
    }

    private func scorePosition(in totalWidth: CGFloat) -> CGFloat {
        let half = totalWidth / 2
        let offset = (evaluation / 300.0) * half
        return half + max(-half, min(half, offset))
    }
}

// MARK: - MoveListView

struct MoveListView: View {
    let moves: [String]
    let currentIndex: Int

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(moves.enumerated()), id: \.offset) { index, move in
                    let moveNumber = (index / 2) + 1
                    let isWhiteMove = index % 2 == 0

                    if isWhiteMove {
                        Text("\(moveNumber).")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.textMuted)
                    }

                    Text(move)
                        .font(.system(size: 12, weight: currentIndex == index ? .bold : .regular, design: .monospaced))
                        .foregroundColor(currentIndex == index ? theme.primary : theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(currentIndex == index ? theme.primary.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(theme.surface)
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - RatingBadge

struct RatingBadge: View {
    let rating: Int
    let size: CGFloat

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.surface)
                .overlay(
                    Circle()
                        .stroke(ratingColor, lineWidth: 3)
                )

            VStack(spacing: 0) {
                Text("\(rating)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text("Elo")
                    .font(.system(size: size * 0.15, weight: .medium))
                    .foregroundColor(theme.textMuted)
            }
        }
        .frame(width: size, height: size)
    }

    private var ratingColor: Color {
        switch rating {
        case ..<1000: return .gray
        case 1000..<1400: return .green
        case 1400..<1800: return theme.primary
        case 1800..<2200: return .blue
        default: return .purple
        }
    }
}
