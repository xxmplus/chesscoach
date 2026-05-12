import Foundation

// MARK: - UCIParser

/// Parses UCI protocol output lines from Stockfish/Lc0 into structured types.
public enum UCIParser {
    /// Parses an "info" line and extracts EngineLine if it contains a pv.
    /// e.g. `info depth 20 seldepth 25 multipv 1 score cp 42 pv e2e4 e7e5`
    public static func parseInfoLine(_ line: String) -> (depth: Int, score: EngineScore, moves: [String], pv: String)? {
        guard line.hasPrefix("info"), line.contains("pv") else { return nil }

        var depth = 0
        var score: EngineScore?
        var moves: [String] = []

        let tokens = line.split(separator: " ").map(String.init)

        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "depth":
                i += 1
                if i < tokens.count { depth = Int(tokens[i]) ?? 0 }
            case "score":
                i += 1
                if i < tokens.count {
                    var bound: String?
                    if tokens[i] == "upperbound" || tokens[i] == "lowerbound" {
                        bound = tokens[i]
                        i += 1
                    }

                    let type = tokens[i]
                    i += 1
                    if i < tokens.count, let value = Int(tokens[i]) {
                        if i + 1 < tokens.count, tokens[i + 1] == "upperbound" || tokens[i + 1] == "lowerbound" {
                            bound = tokens[i + 1]
                        }

                        switch type {
                        case "cp":
                            if bound == "upperbound" { score = .upperBound(value) }
                            else if bound == "lowerbound" { score = .lowerBound(value) }
                            else { score = .cp(value) }
                        case "mate": score = .mate(value)
                        default: break
                        }
                    }
                }
            case "pv":
                i += 1
                moves = Array(tokens[i...])
                break
            default: break
            }
            i += 1
        }

        guard let s = score, !moves.isEmpty else { return nil }
        return (depth, s, moves, moves.joined(separator: " "))
    }

    /// Parses a "bestmove" line.
    /// e.g. `bestmove e2e4 ponder d2d4`
    public static func parseBestMove(_ line: String) -> (bestMove: String, ponder: String?) {
        let tokens = line.split(separator: " ").map(String.init)
        guard tokens.count >= 2, tokens[0] == "bestmove" else {
            return ("", nil)
        }
        let best = tokens[1]
        var ponder: String? = nil
        if tokens.count >= 4, tokens[2] == "ponder" {
            ponder = tokens[3]
        }
        return (best, ponder)
    }
}
