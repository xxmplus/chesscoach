import SwiftUI
import ChessCoachShared
import ChessCoachEngine

struct EnginePanelView: View {
    @ObservedObject var vm: PlayViewModel
    @Environment(\.dismiss) private var dismiss

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Analysis Depth")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)

                Stepper("Depth: \(vm.analysisDepth)", value: $vm.analysisDepth, in: 1...30)
                    .foregroundColor(theme.textPrimary)

                Toggle("Use depth limit", isOn: $vm.useDepthLimit)
                    .foregroundColor(theme.textPrimary)

                if !vm.useDepthLimit {
                    VStack(alignment: .leading) {
                        Text("Time: \(String(format: "%.1f", vm.analysisTime))s")
                            .font(.subheadline)
                            .foregroundColor(theme.textMuted)
                        Slider(value: $vm.analysisTime, in: 0.5...10.0, step: 0.5)
                            .tint(theme.primary)
                    }
                }

                Divider()

                Text("Top Lines")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)

                if vm.engineLines.isEmpty {
                    Text("Run analysis to see top lines")
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                } else {
                    ForEach(Array(vm.engineLines.prefix(3).enumerated()), id: \.offset) { index, line in
                        EngineLineRow(line: line, index: index)
                    }
                }

                Spacer()
            }
            .padding()
            .background(theme.background)
            .navigationTitle("Engine Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.primary)
                }
            }
        }
    }
}

struct EngineLineRow: View {
    let line: EngineLine
    let index: Int

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        HStack {
            Text("\(index + 1).")
                .font(.caption.bold())
                .foregroundColor(theme.textMuted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(line.moves.prefix(4).joined(separator: " "))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                Text("depth \(line.depth)")
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            Text(line.score.displayString)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundColor(scoreColor)
        }
        .padding(10)
        .background(theme.surface)
        .cornerRadius(8)
    }

    private var scoreColor: Color {
        guard let cp = line.score.centipawns else { return theme.textMuted }
        if cp > 50 { return theme.secondary }
        if cp < -50 { return theme.accent }
        return theme.textMuted
    }
}
