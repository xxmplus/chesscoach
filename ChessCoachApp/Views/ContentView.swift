import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(0)

            PuzzlesView()
                .tabItem { Label("Puzzles", systemImage: "puzzlepiece.fill") }
                .tag(1)

            PlayView()
                .tabItem { Label("Play", systemImage: "play.circle.fill") }
                .tag(2)

            ProgressView()
                .tabItem { Label("Me", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(ChessTheme.midnightStudy.primary)
    }
}
