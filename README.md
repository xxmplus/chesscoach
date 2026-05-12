# ChessCoach

ChessCoach is an iPhone chess-training app for adult beginners who want to reach club-level strength. It combines a structured curriculum, tactic puzzles, free position analysis, Stockfish-powered evaluation, and local LLM coaching.

The app uses a dark “Midnight Study” design language and is built as a SwiftUI/XcodeGen multi-target iOS project.

## Features

- **Learn** — opening, middlegame, and endgame lessons with local progress tracking.
- **Puzzles** — interactive tactics with hints, feedback, ratings, and multi-move solutions.
- **Play & Analyze** — interactive board, FEN loading, legal move validation, move history, analysis depth controls, best-move display, and evaluation bar.
- **AI Coach** — local coach pipeline that explains Stockfish analysis in beginner-friendly language.
- **Progress** — estimated Elo, puzzle/lesson counts, streaks, rating history, and weakness tracking.
- **On-device model support** — bundled GGUF model lookup/download infrastructure using DeepSeek-R1 Distill Qwen 1.5B as the active model.

See [`USER_MANUAL.md`](USER_MANUAL.md) for end-user usage and iPhone installation instructions.

## Project Structure

```text
ChessCoachApp/          SwiftUI iOS application
ChessCoachShared/       Board model, pieces, moves, FEN, themes, persistence helpers
ChessCoachEngine/       ChessEngine protocol, Stockfish adapter, Lc0 adapter hook, LLM service
ChessCoachCoach/        Lessons, puzzles, opening book, coach engine, progress tracker
*Tests/                 Unit test targets for app, shared, engine, and coach layers
project.yml             XcodeGen project definition
SPEC.md                 Product/technical specification
TEST_PLAN.md            Test plan
USER_MANUAL.md          User-facing manual
```

## Requirements

- macOS with Xcode
- iOS 17.0+ target device/simulator
- XcodeGen
- Swift 5.9 / Xcode 16 project settings

Install XcodeGen if needed:

```bash
brew install xcodegen
```

## Build

Generate the Xcode project:

```bash
xcodegen generate
```

Open in Xcode:

```bash
open ChessCoach.xcodeproj
```

Or build from the terminal:

```bash
xcodebuild \
  -project ChessCoach.xcodeproj \
  -scheme ChessCoachApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  clean build
```

If your simulator name differs, list destinations:

```bash
xcodebuild -project ChessCoach.xcodeproj -scheme ChessCoachApp -showdestinations
```

## Test

Run the full test suite:

```bash
xcodebuild \
  -project ChessCoach.xcodeproj \
  -scheme ChessCoachApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

## Install on iPhone

1. Run `xcodegen generate`.
2. Open `ChessCoach.xcodeproj`.
3. Select the `ChessCoachApp` scheme.
4. Select your connected iPhone as the destination.
5. Configure signing under **Signing & Capabilities**.
6. Press `Cmd+R`.

More detailed steps are in [`USER_MANUAL.md`](USER_MANUAL.md).

## Local Engine and Model Notes

- Stockfish is the default analysis engine path.
- `Lc0Adapter` is present as an alternate/future adapter hook.
- The active local LLM model is:

```text
ChessCoachShared/Models/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf
```

The chess engine evaluates positions. The LLM coach explains engine output; it is not the source of chess evaluation truth.

## License

MIT. See [`LICENSE`](LICENSE).
