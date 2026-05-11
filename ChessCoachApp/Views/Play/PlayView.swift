import SwiftUI

struct PlayView: View {
    @EnvironmentObject private var engineManager: EngineManager
    @StateObject private var vm = PlayViewModel()
    @State private var showEnginePanel = false

    private let theme = ChessTheme.midnightStudy

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Engine status
                    HStack {
                        Circle()
                            .fill(engineManager.isEngineReady ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(engineManager.engineName)
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                        Spacer()
                        Button {
                            showEnginePanel.toggle()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(theme.primary)
                        }
                    }
                    .padding(.horizontal)

                    // Board
                    GeometryReader { geo in
                        let boardSize = min(geo.size.width - 32, geo.size.height - 200)
                        ChessBoardView(
                            position: $vm.position,
                            interactive: true,
                            engineLines: vm.engineLines
                        ) { move in
                            vm.makeMove(move)
                        }
                        .frame(width: boardSize, height: boardSize)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.surface)
                        .cornerRadius(12)
                    }
                    .frame(maxHeight: 450)

                    // Evaluation bar
                    if let firstLine = vm.engineLines.first {
                        EvaluationBar(line: firstLine)
                            .frame(height: 24)
                            .padding(.horizontal)
                    }

                    // Best move indicator
                    if let best = vm.bestMove {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(theme.secondary)
                            Text("Best: \(best)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(theme.textMuted)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // Move history
                    MoveListView(moves: vm.moveHistory, currentIndex: vm.currentMoveIndex)
                        .frame(maxHeight: 120)

                    // Analysis controls
                    HStack(spacing: 16) {
                        Toggle("Analysis", isOn: Binding(
                            get: { vm.isAnalyzing },
                            set: { _ in vm.toggleAnalysis() }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: theme.primary))
                        .foregroundColor(theme.textPrimary)

                        Stepper("Depth: \(vm.analysisDepth)", value: $vm.analysisDepth, in: 1...30)
                            .foregroundColor(theme.textMuted)
                    }
                    .font(.caption)
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // FEN input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Load Position")
                            .font(.caption.bold())
                            .foregroundColor(theme.textMuted)
                        HStack {
                            TextField("Paste FEN here...", text: $vm.fenInput)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(theme.textPrimary)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(theme.surfaceLight)
                                .cornerRadius(8)
                            Button("Load") {
                                vm.loadFen()
                            }
                            .font(.caption.bold())
                            .foregroundColor(theme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.primary.opacity(0.15))
                            .cornerRadius(8)
                        }
                        Button("Reset to start") {
                            vm.loadStartingPosition()
                        }
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                    }
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(theme.background)
            .navigationTitle("Play & Analyze")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEnginePanel) {
                EnginePanelView(vm: vm)
                    .presentationDetents([.medium])
            }
            .onAppear {
                vm.setEngine(engineManager.engine)
            }
            .onChange(of: engineManager.engine) { _, newEngine in
                vm.setEngine(newEngine)
            }
        }
    }
}
