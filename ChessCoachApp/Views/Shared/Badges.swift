import SwiftUI
import ChessCoachShared

// MARK: - DifficultyBadge

struct DifficultyBadge: View {
    let difficulty: Int

    private var color: Color {
        switch difficulty {
        case ..<900:   return .green
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
