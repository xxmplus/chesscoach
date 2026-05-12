import SwiftUI
import ChessCoachShared
import ChessCoachEngine
import ChessCoachCoach

// MARK: - CoachView

/// Displays coach messages as a speech-bubble chat history.
/// Presented as a sheet from PlayView after the user makes a move.
struct CoachView: View {
    let messages: [CoachMessage]
    let onDismiss: () -> Void
    let onShowHint: () -> Void

    @State private var showHint = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .background(Color(hex: "1a1a2e"))
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Coach")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Dismiss") { onDismiss() }
                            .foregroundColor(Color(hex: "a0a0c0"))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showHint.toggle() }) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .toolbarBackground(Color(hex: "1a1a2e"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func messageBubble(_ message: CoachMessage) -> some View {
        let isUser = false // Coach messages are always from the coach (left-aligned)
        let alignment: HorizontalAlignment = isUser ? .trailing : .leading
        let bgColor = bubbleColor(for: message)
        let textColor = Color(hex: "e0e0f0")

        VStack(alignment: alignment, spacing: 4) {
            // Category label
            Text(message.category.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(categoryColor(message.category))
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                .padding(.top, 4)

            // Speech bubble
            Text(LocalizedStringKey(message.content))
                .font(.body)
                .foregroundColor(textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(bgColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(borderColor(for: message), lineWidth: message.annotation?.moveQuality != nil ? 1.5 : 0)
                        )
                )
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

            // Quality badge (if available)
            if let quality = message.annotation?.moveQuality {
                Text(quality.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(qualityColor(quality))
                    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            }

            // Evaluation (if available)
            if let eval = message.annotation?.evaluation {
                Text("eval: \(eval > 0 ? "+" : "")\(String(format: "%.1f", Double(eval) / 100.0))")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "8080a0"))
                    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            }
        }
    }

    private func bubbleColor(for message: CoachMessage) -> Color {
        switch message.tone {
        case .encouraging:  return Color(hex: "1a3a2a")
        case .explanatory:  return Color(hex: "1a2a3a")
        case .cautionary:   return Color(hex: "3a2a1a")
        case .directive:    return Color(hex: "2a2a3a")
        case .reflective:   return Color(hex: "1e1e30")
        }
    }

    private func borderColor(for message: CoachMessage) -> Color {
        switch message.annotation?.moveQuality {
        case .brilliant:          return .yellow
        case .great:              return .green
        case .good, .best:         return Color(hex: "3a6a3a")
        case .mistake:             return .orange
        case .blunder:             return .red
        case .inaccuracy,
             .interesting,
             .dubious,
             .none:                 return .clear
        }
    }

    private func categoryColor(_ category: CoachMessage.Category) -> Color {
        switch category {
        case .praise, .moveExplanation, .patternSpot:     return .green
        case .warning, .moveComparison, .whatIfAnalysis:  return .orange
        case .tactical, .exercise:                        return .purple
        case .principle, .opening, .endgame, .middlegame: return .blue
        case .longTerm, .shortTerm, .strategic:           return .cyan
        case .candidateAnalysis:                           return .yellow
        }
    }

    private func qualityColor(_ quality: MoveQuality) -> Color {
        switch quality {
        case .brilliant:          return .yellow
        case .great:              return .green
        case .good, .best:       return Color(hex: "60c060")
        case .inaccuracy:        return Color(hex: "ffa500")
        case .mistake:            return .orange
        case .blunder:            return .red
        case .interesting, .dubious: return .gray
        }
    }
}

// MARK: - CoachViewModel

/// Manages coach message generation and display state.
@MainActor
final class CoachViewModel: ObservableObject {
    @Published var messages: [CoachMessage] = []
    @Published var isLoading = false
    @Published var isVisible = false

    private let coachManager: CoachManager

    init(coachManager: CoachManager) {
        self.coachManager = coachManager
    }

    /// Generate coach explanation for a move that was just played.
    func explainMove(
        move: Move,
        position: Position,
        bestMove: Move?,
        engineEval: EngineLine,
        engineCandidates: [EngineLine]
    ) {
        isLoading = true
        messages = []

        Task {
            let explanations = await coachManager.generateMoveExplanation(
                move: move,
                position: position,
                engineEval: engineEval,
                engineCandidates: engineCandidates,
                bestMove: bestMove
            )

            await MainActor.run {
                self.messages = explanations
                self.isLoading = false
                self.isVisible = true
            }
        }
    }

    func dismiss() {
        isVisible = false
    }
}
