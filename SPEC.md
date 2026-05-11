# ChessCoach — iOS App Specification

## 1. Concept & Vision

ChessCoach is a beginner-to-intermediate chess tutor that ships with a local chess engine (Stockfish, swappable for Lc0) and a structured curriculum targeting FIDE 1800. The app feels like a patient, knowledgeable coach sitting beside you — explaining *why* a move is good or bad, not just whether it is. It combines a graded lesson system, tactic puzzles, opening training, and game analysis, all driven by the same engine that powers real competitive play.

**Target user:** An adult beginner who has learned the rules and wants to reach club-level competence (approx. 1800 FIDE).

---

## 2. Design Language

### Aesthetic Direction
"Midnight Study" — the feel of a quiet chess club at night: dark walnut wood tones, warm amber accents, precise typography. Not gamified, not childish. Clean geometry, subtle shadows, premium tactile feel.

### Color Palette
| Role        | Hex       | Usage                          |
|-------------|-----------|--------------------------------|
| Background  | `#1A1612` | Main app background            |
| Surface      | `#2A2420` | Cards, sheets, panels          |
| SurfaceLight| `#3A3430` | Elevated surfaces, borders     |
| Primary     | `#E8A838` | Gold/amber — CTA, highlights   |
| Secondary   | `#7EC8A0` | Sage green — correct moves     |
| Accent      | `#C85A3A` | Warm red — mistakes, warnings  |
| TextPrimary | `#F5F0E8` | Main text                      |
| TextMuted   | `#9A9088` | Captions, secondary labels    |
| WhiteSquare | `#D4C4A8` | Board light squares            |
| BlackSquare | `#8B7355` | Board dark squares             |

### Typography
- **Display / Headings:** `Playfair Display` (Google Fonts, serif, elegant)
- **Body / UI:** `Source Sans 3` (Google Fonts, readable, neutral)
- **Monospace (moves, PGN, eval):** `JetBrains Mono` (Google Fonts)

### Spatial System
- Base unit: 8pt grid
- Component padding: 16pt
- Card radius: 12pt
- Section spacing: 32pt

### Motion Philosophy
- **Board moves:** 200ms ease-out piece slide
- **Feedback reveals:** 300ms fade + slight scale
- **Sheet transitions:** 350ms iOS sheet presentation
- **No gratuitous animation** — every motion has semantic meaning

### Visual Assets
- SF Symbols for all icons (chess pieces via custom SVG assets)
- Custom chess piece SVG set (Merida orα style)
- No emoji

---

## 3. Layout & Structure

### Tab-Based Navigation (UITabBarController)

```
┌─────────────────────────────────────────────────────┐
│  Tab: Learn    Tab: Puzzles   Tab: Play   Tab: Me   │
├─────────────────────────────────────────────────────┤
│                                                     │
│              Content per tab                        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Screens

1. **Learn** — Curriculum browser: phases (Opening, Middlegame, Endgame), lessons within each phase, progress indicators
2. **Puzzles** — Daily puzzle, puzzle streaks, rated puzzle sets by difficulty band
3. **Play** — Analyse any FEN/PGN position; import from clipboard; paste game notation
4. **Me** — Player profile, rating projection, session history, settings (engine strength, theme)

### Navigation within tabs
- `UINavigationController` per tab, push-driven for drill-down
- Modal sheets for lesson detail, puzzle solve, engine analysis panel

### Responsive Strategy
- Portrait-primary design
- Landscape board view for puzzle/analysis
- iPhone only (no iPad split-view optimisation required for v1)

---

## 4. Features & Interactions

### 4.1 Lesson System

- **Curriculum phases:** Opening → Middlegame → Endgame
- **Lessons:** Each lesson has a title, difficulty rating (Elo estimate), body text, embedded positions (FEN), and a "try it" interactive board
- **Lesson states:** `not_started | in_progress | completed`
- **Interactions:** Read theory → Load position on board → Make moves as instructed → Receive engine feedback → Mark complete
- **Progress:** 1–3 stars per lesson based on attempts; stored locally

### 4.2 Puzzle Engine

- **Puzzle format:** Standard "find the best move" (or sequence) with a known solution path
- **Hint system:** Progressive hints (1st hint: piece that should move / 2nd hint: full move notation)
- **Feedback:** After correct move — short explanation text. After wrong move — show engine-preferred line + explanation
- **Rating:** Puzzle difficulty rated from 600–2400 Elo; app tracks solved/unsolved and adjusts presented difficulty
- **Streak tracking:** Daily streak, best streak, streak-protected by completing without hints

### 4.3 Opening Book

- **Pre-loaded** short list of common openings (Italian, Sicilian, Queen's Gambit, etc.) with one-line description and model games
- **Interactive:** User plays moves; engine supplies the "book move" if the position is in the opening book, otherwise falls back to engine evaluation
- **Bookmarking:** Save positions to a "my openings" list

### 4.4 Game / Position Analysis

- **FEN input:** Paste or type FEN → load position on board
- **PGN import:** Paste game notation → step through move-by-move with engine evaluation alongside each move
- **Engine panel:** Slides up from bottom; shows top-3 lines with evaluations and move arrows on the board
- **Configurable depth / time:** Slider to set engine thinking depth (1–30) or time limit (0.5s–10s)
- **Share analysis:** Export annotated PGN

### 4.5 Engine Architecture (pluggable)

```
┌─────────────────────┐
│   ChessEngine       │  ← Protocol
│   Protocol          │
└────────┬────────────┘
         │ concrete adapters
    ┌────┴────┐
    ▼         ▼
Stockfish  Lc0Adapter
Adapter    (future)
```

- `ChessEngine` protocol defines: `startAnalysis(position: Fen, depth: Int)`, `stopAnalysis()`, `bestMove()`, `evaluation()`
- `StockfishAdapter`: spawns `stockfish` process via stdin/stdout, maps UCI output to `EngineLine` structs
- `Lc0Adapter`: same protocol, different binary + UCI-like commands
- Engines are bundled as resources or downloaded on first launch from a known URL

### 4.6 Progress Tracking

- Estimated Elo displayed (based on puzzle performance + lesson completion)
- Session log: date, activity type, result
- Weakness map: which opening/middlegame themes the user struggles with
- Weekly review summary

### 4.7 Settings

- Engine selection (Stockfish default, Lc0 if available)
- Engine strength (Elo cap: 1000–2800, maps to depth/hash)
- Board theme (classic walnut, light, high-contrast)
- Sound effects (move sounds, check notification)
- Reset progress

---

## 5. Component Inventory

### ChessBoardView
- 8×8 grid with light/dark squares
- Pieces rendered as custom SVG (white/black full sets)
- **States:** `interactive`, `static`, `analysis_overlay`
- `interactive`: user can drag pieces; highlights legal destination squares on drag-start
- `analysis_overlay`: shows arrows for top-3 engine lines with color-codedEval (green=positive, red=negative)
- Last move highlight (yellow tint on from/to squares)
- Check highlight (red tint on king square)

### PieceView
- Single chess piece, resizable
- Supports drag gesture
- SF Symbol fallback for development

### MoveListView
- Scrollable list of moves in algebraic notation (e.g., "1. e4 e5 2. Nf3 Nc6")
- Current move highlighted
- Tap to jump to position

### EvaluationBar
- Horizontal bar, centre-anchored
- Left = black advantage, right = white advantage
- Width proportional to centipawn eval (clamped to ±10 pawns visually)
- Colour: gradient from red (black winning) through neutral grey to green (white winning)

### PuzzleCard
- Compact card: puzzle number, difficulty stars, theme tags
- Swipe to dismiss (mark as too easy / too hard)
- Correct/incorrect inline feedback

### LessonRow
- Row with: phase icon, lesson title, difficulty badge, star progress, chevron
- States: locked, available, in-progress, completed

### EngineLineView
- Shows: move arrow (UCI format), centipawn eval, win% (if available), depth
- Tappable: loads that line on the board

### RatingBadge
- Circular badge: current Elo estimate
- Animates on change (counting up/down)

---

## 6. Technical Approach

### Platform & Toolchain
- **iOS 16.0+**, Swift 5.9, SwiftUI (primary UI) + UIKit (board view)
- **XcodeGen** for project generation
- **Swift Package Manager** for dependency resolution

### Architecture
- **MVVM** with SwiftUI `ObservableObject` ViewModels
- **Combine** for async engine output streams
- **Protocol-oriented engine layer** for pluggability

### Frameworks / Libraries
| Library          | Purpose                          | Manager |
|-----------------|----------------------------------|---------|
| ChessKit         | Move generation, validation, FEN/PGN parsing | SPM |
| Stockfish (binary)| UCI engine (bundled asset or downloaded) | Asset |
| HighlightSwift  | Syntax-highlighted move notation | SPM |
| swift-algorithms| Sequence utilities               | SPM |

### Targets

```
ChessCoachApp          ← Main iOS app target
ChessCoachEngine       ← Protocol + StockfishAdapter + Lc0Adapter shim
ChessCoachCoach        ← Lesson/Puzzle/Opening content + ProgressTracker
ChessCoachShared       ← Board model, FEN, Piece, Move, Square, Theme types
```

### Engine Integration
- Stockfish: macOS/iOS binary from https://stockfishchess.org/files/ (static binary, ~50MB)
- On first launch: copy binary to app's Documents directory; if not present, download from URL
- Engine runs as a background process with `Process` (macOS) / `NSTask`-equivalent on iOS
- UCI protocol parsed line-by-line with a Combine `PassthroughSubject<String, Never>` → structured `EngineLine` events

### Data Persistence
- **UserDefaults:** settings, engine config, streak counter
- **SQLite.swift:** lessons, puzzles, session log, rating history
- **FileManager:** downloaded engine binaries, PGN game archive

### Content Pipeline
- Lessons and puzzles shipped as JSON assets in the bundle (`lessons.json`, `puzzles.json`)
- Schema documented below

### Asset Requirements
- 12 SVG piece images (K Q R B N P × white/black)
- App icon (1024×1024 + all sizes)
- Tab bar icons (SF Symbols: `book.fill`, `puzzlepiece.fill`, `play.circle.fill`, `person.fill`)

---

## 7. Data Schemas

### Lesson JSON (`lessons.json`)
```json
{
  "lessons": [
    {
      "id": "op-001",
      "phase": "opening",
      "title": "The Italian Game",
      "difficulty": 1000,
      "body": "HTML string with lesson content...",
      "position": {
        "fen": "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3",
        "moves": ["e5", "Nf3"],
        "explanation": "Why 1...e5 and 2...Nf3..."
      },
      "stars": { "one": 2, "two": 1, "three": 0 }
    }
  ]
}
```

### Puzzle JSON (`puzzles.json`)
```json
{
  "puzzles": [
    {
      "id": "p-001",
      "fen": "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 3 3",
      "solution": ["Nf3", "Nc6", "Bb5"],
      "themes": ["fork", "pin"],
      "difficulty": 800,
      "rating": 850,
      "hints": ["White's knight should move", "Nxe5"]
    }
  ]
}
```

---

## 8. File Structure

```
chesscoach/
├── SPEC.md
├── project.yml                    ← XcodeGen config
├── Podfile                        ← (empty, SPM only)
├── ChessCoachApp/
│   ├── App/
│   │   └── ChessCoachApp.swift
│   ├── Views/
│   │   ├── Board/
│   │   │   ├── ChessBoardView.swift
│   │   │   ├── SquareView.swift
│   │   │   └── PieceView.swift
│   │   ├── Learn/
│   │   │   ├── LearnView.swift
│   │   │   ├── LessonDetailView.swift
│   │   │   └── LessonRowView.swift
│   │   ├── Puzzles/
│   │   │   ├── PuzzlesView.swift
│   │   │   └── PuzzleCardView.swift
│   │   ├── Play/
│   │   │   ├── PlayView.swift
│   │   │   └── EnginePanelView.swift
│   │   ├── Progress/
│   │   │   └── ProgressView.swift
│   │   └── Shared/
│   │       ├── EvaluationBar.swift
│   │       ├── MoveListView.swift
│   │       └── RatingBadge.swift
│   ├── ViewModels/
│   │   ├── LearnViewModel.swift
│   │   ├── PuzzleViewModel.swift
│   │   ├── PlayViewModel.swift
│   │   └── ProgressViewModel.swift
│   ├── Assets.xcassets/
│   └── Info.plist
├── ChessCoachEngine/
│   ├── ChessEngine.swift          ← Protocol
│   ├── StockfishAdapter.swift
│   ├── Lc0Adapter.swift           ← Future stub
│   ├── EngineLine.swift
│   ├── UCIParser.swift
│   └── Info.plist
├── ChessCoachCoach/
│   ├── LessonLibrary.swift
│   ├── PuzzleEngine.swift
│   ├── OpeningBook.swift
│   ├── ProgressTracker.swift
│   ├── ContentLoader.swift
│   └── Info.plist
└── ChessCoachShared/
    ├── Models/
    │   ├── Piece.swift
    │   ├── Square.swift
    │   ├── Move.swift
    │   ├── Position.swift         ← FEN parsing / board state
    │   └── Theme.swift
    ├── Persistence/
    │   └── DatabaseManager.swift
    └── Info.plist
```
