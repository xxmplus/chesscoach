# ChessCoach — Test Plan

## Build Verification

```bash
cd ~/ssd/workspaces/chesscoach
xcodebuild -project ChessCoach.xcodeproj \
  -scheme ChessCoachApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Expected: **`BUILD SUCCEEDED`** with zero errors.

---

## Module Architecture

```
ChessCoachApp          → SwiftUI app, Views, ViewModels
ChessCoachEngine      → ChessEngine protocol, StockfishAdapter (WASM), Lc0Adapter
ChessCoachCoach       → LessonLibrary, PuzzleEngine, OpeningBook, ProgressTracker
ChessCoachShared      → Piece, Square, Move, Position (pure Swift), Theme, DatabaseManager
```

| Target | Dependencies | Notes |
|---|---|---|
| ChessCoachApp | Shared, Engine, Coach | Top-level app |
| ChessCoachEngine | Shared | Protocol + adapters |
| ChessCoachCoach | Shared, Engine | Business logic |
| ChessCoachShared | SQLite.swift | No external framework |

---

## Feature Test Plan

### 1. Pure Swift Move Generation (`Position`)

**Test file:** `ChessCoachShared/Models/Position.swift`

| # | Test Case | Expected Result |
|---|---|---|
| 1.1 | `Position()` — default starting position | FEN `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` |
| 1.2 | `Position(fen: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")` | Parses successfully |
| 1.3 | `startingPosition.legalMoves(from: e2)` | Contains `e4`, `e3` |
| 1.4 | `startingPosition.legalMoves(from: g1)` | Contains `Nf3` (== `f3`), `Nh3` (== `h3`) |
| 1.5 | After `1.e4`, `legalMoves(from: e4)` | Contains `e5` only (pawns can't move backward) |
| 1.6 | `Position(fen: ... "KQkq -")` castling rights — `legalMoves(from: e1)` | Contains `O-O` (e1→g1) and `O-O-O` (e1→c1) |
| 1.7 | `Position(fen: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")` en passant — `legalMoves(from: e4)` | Contains `e4e3` (en passant capture) |
| 1.8 | `startingPosition.isCheck` | `false` |
| 1.9 | Position after `1.e4 d5 2.exd5` — `isCheck` | `false` |
| 1.10 | Position `rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2` — `isCheck` | `false` (black's pawn on e6 doesn't attack e4) |
| 1.11 | Scholar's mate position `r1bqkb1r/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4` — `isCheckmate` | `true` |
| 1.12 | Starting position — `isStalemate` | `false` |
| 1.13 | `makeMove(Move)` on starting position, verify FEN changes | Turn flips to black, halfmove clock increments |
| 1.14 | `hashValue` — two identical positions | Equal |
| 1.15 | `Codable` round-trip `JSONEncoder/Decoder` | Position survives encode→decode |

**Run via:** Xcode unit test target (add `XCTestCase` in `ChessCoachSharedTests/`)

---

### 2. Move Representation (`Move`, `Square`, `Piece`)

| # | Test Case | Expected Result |
|---|---|---|
| 2.1 | `Square(file: 4, rank: 4)` → `.index == 36` | `true` |
| 2.2 | `Square(file: 0, rank: 0)` → `.index == 0` | `true` |
| 2.3 | `Square(file: 7, rank: 7)` → `.index == 63` | `true` |
| 2.4 | `Square(description: "e4")` → `.file == 4, .rank == 3` | `true` |
| 2.5 | `Square(description: "a1")` → `.file == 0, .rank == 0` | `true` |
| 2.6 | `Square(description: "h8")` → `.file == 7, .rank == 7` | `true` |
| 2.7 | `Piece.whiteKing.character` | `"♔"` |
| 2.8 | `Piece.blackQueen.character` | `"♛"` |
| 2.9 | `Move.from.description` for `Move(from: e2, to: e4)` | `"e2"` |
| 2.10 | `Move.fromUci("e2e4")` → `.from.file==4, .from.rank==1, .to.file==4, .to.rank==3` | `true` |
| 2.11 | `Move(from: e2, to: e4).enPassant` | `false` by default |
| 2.12 | Promotion move `e7e8q` — `Move(fromUci: "e7e8q")` → `.promotion == .queen` | `true` |

---

### 3. Lesson Content (`ContentLoader`)

| # | Test Case | Expected Result |
|---|---|---|
| 3.1 | `ContentLoader.shared.loadLessons().count` | `9` |
| 3.2 | Lessons grouped by phase: `filter { $0.phase == .opening }.count` | `3` |
| 3.3 | Lesson `op-001` (Italian Game) — `positions[0].fen` is valid FEN | `true` |
| 3.4 | All 9 lesson FENs pass validation | `true` |
| 3.5 | `ContentLoader.shared.loadPuzzles().count` | `8` |
| 3.6 | All 8 puzzle FENs pass validation | `true` |
| 3.7 | Puzzle `p-001` (rating 600) — `solution.count` ≥ 1 | `true` |
| 3.8 | Puzzle `p-006` (rating 1300) — `solution.count` | `3` (multi-move) |
| 3.9 | Puzzle rating range | `600 ≤ rating ≤ 1650` |
| 3.10 | Each puzzle has ≥ 1 hint | `true` |

---

### 4. Puzzle Engine (`PuzzleEngine`)

| # | Test Case | Expected Result |
|---|---|---|
| 4.1 | Submit correct first move on puzzle `p-002` (Nf3xe5) | `PuzzleResult.correct` |
| 4.2 | Submit wrong move | `PuzzleResult.wrong` |
| 4.3 | Complete full puzzle solution | `PuzzleResult.correct` + `isComplete` |
| 4.4 | Request hint | Returns non-nil string |
| 4.5 | Attempt count tracked | Increments on wrong answer |

**Run via:** `PuzzleEngineTests.swift`

---

### 5. Stockfish Adapter (`StockfishAdapter`)

| # | Test Case | Expected Result |
|---|---|---|
| 5.1 | `StockfishAdapter().displayName` | `"Stockfish (WebAssembly)"` |
| 5.2 | `initialize()` completes without throwing | Engine ready |
| 5.3 | `analyze(fen: startingPosition.fen, depth: 10)` — first `EngineLine` | `score` within ±5 cp of 0.0 (starting position is equal) |
| 5.4 | After analysis, `lastBestMove` is non-nil | Valid UCI move |
| 5.5 | `stopAnalysis()` — publisher completes | `FiniteTimedOut` |
| 5.6 | `shutdown()` — subsequent `analyze()` | Throws or returns no data |
| 5.7 | HTML file loads in `WKWebView` | Stockfish.js engine initializes |

**Note:** Full Stockfish.js binary needs to be bundled for production. Current `StockfishLoader.html` is a minimal stub. See §Stockfish WASM Setup below.

---

### 6. Lc0 Adapter (`Lc0Adapter`)

| # | Test Case | Expected Result |
|---|---|---|
| 6.1 | `Lc0Adapter().displayName` | `"Lc0 (Leela Chess Zero)"` |
| 6.2 | `Lc0Adapter().isAvailable` | `false` (stub — no server bundled) |
| 6.3 | `initialize()` | Throws `EngineError.notAvailable` |

**Integration path:** Bundle `lc0-http` server + `256x10.pb` weights → update `Lc0Adapter`.

---

### 7. Opening Book (`OpeningBook`)

| # | Test Case | Expected Result |
|---|---|---|
| 7.1 | `OpeningBook.shared.suggestMove(fen, playerMove: "e2e4")` | Returns a legal response (e.g. `c7c5` Sicilian) |
| 7.2 | Response is a legal move in the current position | `true` |
| 7.3 | Two identical calls with same FEN | Same response (deterministic) |

---

### 8. Progress Tracking (`ProgressTracker`)

| # | Test Case | Expected Result |
|---|---|---|
| 8.1 | `ProgressTracker().lessonCompleted(id: "op-001", stars: 2)` | No crash |
| 8.2 | `lessonCompleted()` twice with different stars | Stars are `max(prev, new)` |
| 8.3 | `puzzleSolved(rating: 1000, themes: ["fork"])` | No crash |
| 8.4 | `puzzleFailed(rating: 1000)` | No crash |
| 8.5 | `getRatingHistory()` returns array | Non-nil (may be empty) |
| 8.6 | After 3+ puzzles, `getRatingHistory().count >= 1` | `true` |

**Verify via:** SQLite browser — check `~/Library/Developer/Xcode/DerivedData/ChessCoach-*/.../default.store`

---

### 9. Database Persistence (`DatabaseManager`)

| # | Test Case | Expected Result |
|---|---|---|
| 9.1 | `saveLessonProgress()` → `getAllLessonProgress()` | Returns saved data |
| 9.2 | `saveLessonProgress()` with new stars updates existing | Stars reflect maximum |
| 9.3 | App relaunch — progress persists | Data survives cold start |

---

### 10. UI / SwiftUI Views

#### 10.1 Learn Tab

| # | Test Case | Expected Result |
|---|---|---|
| 10.1.1 | Launch → Learn tab selected | Shows 3 phase buttons (Opening / Middlegame / Endgame) |
| 10.1.2 | Tap "Opening" phase | Filters to 3 lessons |
| 10.1.3 | Tap lesson row | Navigates to `LessonDetailView` |
| 10.1.4 | `LessonDetailView` — board renders | 8×8 board, pieces visible |
| 10.1.5 | Tap board piece | Highlights legal destination squares |
| 10.1.6 | Progress header shows `X/9 lessons completed` | Correct count |
| 10.1.7 | Stars badge shows current/total stars | Matches `vm.totalStars` |

#### 10.2 Puzzles Tab

| # | Test Case | Expected Result |
|---|---|---|
| 10.2.1 | Puzzle loads on tab open | Board shows puzzle FEN position |
| 10.2.2 | Tap correct destination square | Feedback: green checkmark, "Correct!" |
| 10.2.3 | Tap wrong square | Feedback: red X, "Not this move" |
| 10.2.4 | Tap "Hint" | Hint text appears below board |
| 10.2.5 | Tap "Skip" | New puzzle loads |
| 10.2.6 | Complete puzzle → "Next Puzzle" button | Appears after final move |
| 10.2.7 | Rating badge shows correct Elo range | Matches puzzle rating |

#### 10.3 Play Tab (Analysis Board)

| # | Test Case | Expected Result |
|---|---|---|
| 10.3.1 | Board renders in starting position | All 32 pieces visible |
| 10.3.2 | Drag piece to legal square | Move applies, turn flips |
| 10.3.3 | Tap piece → tap destination | Same as drag (touch-to-move) |
| 10.3.4 | Engine panel shows engine name | "Stockfish (WebAssembly)" |
| 10.3.5 | After 3+ seconds of analysis | Evaluation bar updates, top line shows score |
| 10.3.6 | Evaluation bar — equal position | Bar centered (score ≈ 0.0) |
| 10.3.7 | Tap "Flip Board" | Board rotates 180° |
| 10.3.8 | Engine arrows display | Green arrow on best move |

#### 10.4 Progress Tab

| # | Test Case | Expected Result |
|---|---|---|
| 10.4.1 | Estimated rating badge shows | Non-zero number |
| 10.4.2 | Lesson completion ring | Shows `completedCount/9` |
| 10.4.3 | Rating history chart | At least 1 data point after puzzles |

---

## Non-Functional Tests

| # | Test | Expected Result |
|---|---|---|
| N.1 | Build on macOS 15 + Xcode 16 | `BUILD SUCCEEDED` |
| N.2 | Run on iPhone simulator (iOS 17) | App launches, all tabs navigable |
| N.3 | Memory: 10 puzzle completions | No memory growth (test via Instruments) |
| N.4 | Stockfish analysis: 30-second sustained | No crash, engine continues outputting |
| N.5 | App cold start | Launches within 3 seconds |
| N.6 | SQLite database created | `chesscoach.store` in app Documents |

---

## Known Gaps (Future Work)

### Stockfish WASM Setup
The `StockfishLoader.html` is a minimal stub. For real engine analysis:

1. Download Stockfish.js from `https://cdn.jsdelivr.net/npm/stockfish.js@10.0.2/stockfish.js`
2. Download `stockfish.wasm` (same release)
3. Place both in `ChessCoachApp/Assets/`
4. Update `StockfishLoader.html` to load the real WASM binary
5. Remove the dummy `sfReady` bootstrap in the HTML

### Lc0 Integration
1. Download `lc0` binary + `256x10.pb` weights from lczero.org
2. Bundle `lc0-http` server wrapper
3. Wire `Lc0Adapter` to `URLSessionWebSocketTask`
4. Set `isAvailable = true` when server responds

### Content Expansion
- **Lessons:** Expand from 9 → ~50 (full opening repertoire, tactical themes, endgame fundamentals)
- **Puzzles:** Lizards database or Chess.com puzzle API for thousands of rated positions
- **Opening book:** PGN import from Lichess opening book (CC-BY-SA)

### App Store Distribution
- Requires paid Apple Developer account ($99/yr)
- Set `DEVELOPMENT_TEAM` in `project.yml`
- Archive → Validate → Distribute via App Store Connect

---

## Running the Full Test Suite

```bash
# 1. Verify build
xcodebuild -project ChessCoach.xcodeproj \
  -scheme ChessCoachApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build

# 2. Run unit tests (add test target first)
xcodebuild test \
  -scheme ChessCoachShared \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 3. Open in Xcode for manual UI testing
open ChessCoach.xcodeproj
# Select iPhone 17 simulator, press ⌘R
```
