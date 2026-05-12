# ChessCoach User Manual

ChessCoach is an iPhone chess-training app for adult beginners who want to reach club-level strength. It combines structured lessons, tactic puzzles, position analysis, engine feedback, and local AI coaching in a dark “Midnight Study” interface.

This manual explains what the app currently supports, how to use each screen, and how to install it on an iPhone from Xcode.

---

## 1. Requirements

### iPhone

- iOS 17.0 or newer
- Enough free storage for the app and bundled model assets
- Recommended: iPhone 13 or newer

### Mac for installation

To install the development build onto an iPhone you need:

- macOS with Xcode installed
- Xcode command line tools
- XcodeGen installed
- Apple ID signed into Xcode
- USB cable or enabled wireless device pairing

The app is not yet distributed through the App Store/TestFlight in this repository. Installation is currently through Xcode.

---

## 2. Supported Features

### Learn tab

The Learn tab provides a structured curriculum split into:

- Opening
- Middlegame
- Endgame

Current built-in lessons include:

| Phase | Lessons |
|---|---|
| Opening | Italian Game, Sicilian Defense, Development Principles |
| Middlegame | Forks, Pins and Skewers, Discovered Attacks |
| Endgame | Queen Checkmate, Opposition, Lucena Position |

Supported lesson features:

- Browse lessons by phase
- See lesson difficulty as an Elo-style number
- Open lesson detail pages
- Read explanatory lesson text
- Study a built-in board position for each lesson
- Complete lessons manually
- Earn 0–3 stars depending on attempts
- Persist lesson progress locally

### Puzzles tab

The Puzzles tab presents tactic puzzles from the built-in puzzle set.

Supported puzzle features:

- Interactive board solving
- UCI-style solution checking internally
- Single-move and multi-move puzzle sequences
- Puzzle themes such as fork, checkmate, tactics, attack, opening, exchange
- Elo-style puzzle ratings from beginner to intermediate range
- Progressive hints
- Wrong-move feedback
- Correct-move feedback
- Skip puzzle
- Next puzzle after solving

Current built-in puzzle ratings range from about 600 to 1650.

### Play tab

The Play tab is for free play and position analysis.

Supported play/analysis features:

- Interactive chess board
- Legal move validation through the internal `Position` model
- Move history display
- Reset to starting position
- Paste/load a FEN position
- Start/stop engine analysis
- Configure analysis depth from 1 to 30
- Show engine lines on the board/analysis UI
- Show current best move when analysis is available
- Evaluation bar based on engine output
- Coach explanation sheet after user moves, when engine/coach services are available

### Me tab

The Me tab tracks training progress.

Supported progress features:

- Estimated Elo display
- Rating label, for example Beginner, Novice, Intermediate, Club Player
- Total puzzles solved
- Total lessons completed
- Current day streak
- Best day streak
- Areas to improve based on puzzle themes where mistakes/hints occurred
- Rating history chart when history exists

Progress is stored locally on the device using SQLite/UserDefaults-backed persistence.

---

## 3. Local Engine and AI Coach

ChessCoach is designed around local analysis and local coaching.

### Chess engine

- Default engine path: Stockfish adapter
- Engine protocol is pluggable through `ChessEngine`
- `Lc0Adapter` exists as a future/alternate adapter hook, but Stockfish is the current default path

The engine provides:

- Best move search
- Principal variation lines
- Centipawn/mate-style evaluation parsing
- Evaluation data for the Play screen and coach pipeline

### Local LLM coach

The local coach uses the engine result as truth and turns it into beginner-friendly explanation text.

Active bundled model:

- `DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf`
- Display name: DeepSeek-R1 Distill (1.5B)
- Approximate size: 1.0 GB
- Intended role: explain engine output in clear language, not replace the chess engine

Important behavior:

- Stockfish evaluates positions.
- The LLM explains those evaluations.
- If the LLM is unavailable, the coach system can still fall back to template-style coaching messages.

---

## 4. How to Use the App

### 4.1 Study lessons

1. Open **Learn**.
2. Select a phase: Opening, Middlegame, or Endgame.
3. Tap a lesson row.
4. Read the lesson text and inspect the board position.
5. Try the suggested moves if the lesson includes guided moves.
6. Tap **Complete** when finished.
7. Return to the Learn tab to see stars/progress update.

### 4.2 Solve puzzles

1. Open **Puzzles**.
2. Read the puzzle rating and theme tags.
3. Move a piece on the board.
4. If correct, the app shows positive feedback.
5. If the puzzle has a longer solution sequence, continue entering the next move.
6. If stuck, tap **Hint**.
7. Tap **Skip** to move on without solving.
8. After solving, tap **Next Puzzle**.

### 4.3 Analyze a position

1. Open **Play**.
2. Use the starting position or paste a FEN into **Load Position**.
3. Tap **Load**.
4. Turn on **Analysis**.
5. Adjust **Depth** if needed.
6. Watch the best move/evaluation update as engine analysis returns.
7. Make a legal move on the board.
8. When available, the coach sheet explains the move.

### 4.4 Reset the board

1. Open **Play**.
2. Tap **Reset to start**.
3. Move history, engine lines, and coach messages are cleared.

### 4.5 Track progress

1. Open **Me**.
2. Review estimated Elo, solved puzzles, completed lessons, streaks, and weaknesses.
3. Complete more lessons/puzzles to update the metrics.

---

## 5. Install on iPhone from Xcode

These steps install the development build directly onto your iPhone.

### Step 1 — Open the project directory

```bash
cd /Users/friday/ssd/workspaces/chesscoach
```

### Step 2 — Install XcodeGen if needed

If `xcodegen` is not installed:

```bash
brew install xcodegen
```

### Step 3 — Generate the Xcode project

```bash
xcodegen generate
```

This creates/updates:

```text
ChessCoach.xcodeproj
```

### Step 4 — Open the project

```bash
open ChessCoach.xcodeproj
```

### Step 5 — Connect the iPhone

1. Connect the iPhone to the Mac by USB, or use a previously paired wireless device.
2. Unlock the iPhone.
3. Trust the Mac if iOS asks.
4. In Xcode, select the iPhone as the run destination.

### Step 6 — Configure signing

In Xcode:

1. Select the `ChessCoach` project in the navigator.
2. Select the `ChessCoachApp` target.
3. Open **Signing & Capabilities**.
4. Enable **Automatically manage signing**.
5. Select your Apple Developer Team.
6. If Xcode reports a bundle ID conflict, change the app bundle identifier from:

```text
com.chesscoach.app
```

to something unique, for example:

```text
com.<yourname>.chesscoach
```

For a personal/free Apple ID, the app may need to be reinstalled or re-signed periodically.

### Step 7 — Build and run

In Xcode, press:

```text
Cmd + R
```

Xcode will build, sign, install, and launch ChessCoach on the selected iPhone.

### Step 8 — Trust developer profile if needed

If the iPhone refuses to launch the app:

1. Open iPhone **Settings**.
2. Go to **General → VPN & Device Management**.
3. Select your developer profile.
4. Tap **Trust**.
5. Launch ChessCoach again.

---

## 6. Build from Terminal

To verify a simulator build from the command line:

```bash
cd /Users/friday/ssd/workspaces/chesscoach
xcodegen generate
xcodebuild \
  -project ChessCoach.xcodeproj \
  -scheme ChessCoachApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  clean build
```

To run unit tests:

```bash
xcodebuild \
  -project ChessCoach.xcodeproj \
  -scheme ChessCoachApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

If your installed simulator has a different name, list available destinations with:

```bash
xcodebuild -project ChessCoach.xcodeproj -scheme ChessCoachApp -showdestinations
```

---

## 7. Data and Privacy

Current data storage is local to the device/simulator.

Stored locally:

- Lesson progress
- Puzzle/session activity
- Rating history
- Streak metadata
- Downloaded/bundled model lookup state

No account login is currently required by the app. Engine analysis and LLM coaching are intended to run locally.

---

## 8. Troubleshooting

### The app does not build

Try regenerating the project:

```bash
cd /Users/friday/ssd/workspaces/chesscoach
xcodegen generate
```

Then reopen `ChessCoach.xcodeproj` and build again.

### Xcode says the bundle identifier is unavailable

Change `PRODUCT_BUNDLE_IDENTIFIER` for `ChessCoachApp` in `project.yml` or in Xcode signing settings to a unique value, then regenerate the project.

### My iPhone is not listed as a run destination

Check:

- iPhone is unlocked
- Cable is connected
- Mac is trusted on the iPhone
- Developer Mode is enabled on the iPhone if iOS requires it
- Xcode has finished preparing device support files

### The app installs but will not open

Trust the developer profile:

```text
Settings → General → VPN & Device Management → Trust Developer
```

### Engine status is red or analysis does not produce lines

Possible causes:

- Engine resource failed to initialize
- Build did not include required engine assets
- Running in an environment where the Stockfish bridge/resource is unavailable

The rest of the app should still open, but live engine analysis and coach explanations may be limited.

### Coach explanations are missing

Possible causes:

- Engine analysis did not return a line
- The local GGUF model was not found or loaded
- Device memory is constrained
- LLM service initialization failed

The app can still use core lessons, puzzles, board interaction, and progress tracking.

---

## 9. Current Limitations

Implemented and usable today:

- Learn curriculum
- Puzzle solving
- Play board
- FEN loading
- Engine analysis controls
- Progress dashboard
- Local progress persistence
- Local LLM/coach integration path

Not yet a polished App Store distribution:

- No TestFlight/App Store packaging in this repo yet
- No user account/cloud sync
- No PGN import/export UI despite being part of the broader product spec
- No fully exposed settings screen for theme/engine strength/reset controls
- Lc0 is present as an adapter hook, not the default user-facing engine
- SwiftUI views are optimized for iPhone portrait-first usage

---

## 10. Quick Reference

| Task | Where |
|---|---|
| Study chess concepts | Learn tab |
| Solve tactics | Puzzles tab |
| Analyze a custom position | Play tab → Load Position |
| Turn on engine analysis | Play tab → Analysis toggle |
| Change analysis depth | Play tab → Depth stepper |
| Reset board | Play tab → Reset to start |
| View rating/progress | Me tab |
| Install to iPhone | Xcode → select iPhone → Cmd+R |
