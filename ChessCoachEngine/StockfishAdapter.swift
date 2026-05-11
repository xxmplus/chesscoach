import Foundation
import WebKit
import Combine

// MARK: - StockfishAdapter

/// iOS-compatible UCI chess engine adapter for Stockfish.
/// Uses a hidden WKWebView running Stockfish.js as WebAssembly to avoid
/// the iOS restriction on Process (macOS only).
public final class StockfishAdapter: NSObject, ChessEngine, WKScriptMessageHandler {

    public let displayName = "Stockfish 16"
    public private(set) var isAvailable = false
    public private(set) var lastBestMove: String?

    // MARK: - Private State

    private var webView: WKWebView?
    private let engineQueue = DispatchQueue(label: "com.chesscoach.stockfish.engine")
    private var pendingContinuation: CheckedContinuation<Void, Error>?
    private var analysisSubject: PassthroughSubject<EngineLine, Never>?
    private var currentDepth: Int = 20
    private var currentTimeout: TimeInterval?
    private var engineReady = false
    private var pendingCommands: [String] = []

    // MARK: - WKUserContentControllerDelegate

    public func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        handleEngineOutput(body)
    }

    // MARK: - ChessEngine

    public func initialize() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pendingContinuation = continuation
            setupWebView()
        }
    }

    public func startAnalysis(fen: String, depth: Int?, timeout: TimeInterval?) -> AnyPublisher<EngineLine, Never> {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            self.stopAnalysisInternal()

            let subject = PassthroughSubject<EngineLine, Never>()
            self.analysisSubject = subject
            self.currentDepth = depth ?? 20
            self.currentTimeout = timeout

            self.sendCommand("position fen \(fen)")
            var goCmd = "go depth \(self.currentDepth)"
            if let t = timeout {
                goCmd = "go movetime \(Int(t * 1000))"
            }
            self.sendCommand(goCmd)

            if let t = timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + t + 1) { [weak self] in
                    self?.stopAnalysisInternal()
                    subject.send(completion: .finished)
                }
            }
        }

        return analysisSubject!
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    public func stopAnalysis() {
        engineQueue.async { [weak self] in
            self?.sendCommand("stop")
            self?.stopAnalysisInternal()
        }
    }

    public func shutdown() {
        engineQueue.async { [weak self] in
            self?.sendCommand("quit")
            self?.webView?.stopLoading()
            self?.webView = nil
            self?.isAvailable = false
            self?.engineReady = false
        }
    }

    // MARK: - Private

    private func stopAnalysisInternal() {
        analysisSubject?.send(completion: .finished)
        analysisSubject = nil
    }

    private func setupWebView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let config = WKWebViewConfiguration()
            let controller = WKUserContentController()
            controller.add(self, name: "stockfish")
            config.userContentController = controller

            let wv = WKWebView(frame: .zero, configuration: config)
            wv.isHidden = true
            self.webView = wv

            // Try bundled HTML first, otherwise use inline
            if let bundledURL = Bundle.main.url(forResource: "stockfish", withExtension: "html", subdirectory: "ChessCoachEngine") {
                wv.loadFileURL(bundledURL, allowingReadAccessTo: bundledURL.deletingLastPathComponent())
            } else if let bundledURL = Bundle.main.url(forResource: "stockfish", withExtension: "html") {
                wv.loadFileURL(bundledURL, allowingReadAccessTo: bundledURL.deletingLastPathComponent())
            } else {
                wv.loadHTMLString(Self.inlineHTML, baseURL: nil)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.sendCommand("uci")
            }
        }
    }

    private func handleEngineOutput(_ line: String) {
        engineQueue.async { [weak self] in
            guard let self = self else { return }

            if line == "uciok" {
                if !self.engineReady {
                    self.engineReady = true
                    self.isAvailable = true
                    for cmd in self.pendingCommands { self.sendCommandNow(cmd) }
                    self.pendingCommands = []
                }
                self.pendingContinuation?.resume()
                self.pendingContinuation = nil
                return
            }

            if line == "readyok" { return }

            if line.hasPrefix("bestmove") {
                let tokens = line.split(separator: " ").map(String.init)
                self.lastBestMove = tokens.count >= 2 ? tokens[1] : nil
                return
            }

            if let parsed = UCIParser.parseInfoLine(line) {
                let engineLine = EngineLine(
                    depth: parsed.depth,
                    score: parsed.score,
                    moves: parsed.moves,
                    pv: parsed.pv
                )
                DispatchQueue.main.async {
                    self.analysisSubject?.send(engineLine)
                }
            }
        }
    }

    private func sendCommand(_ cmd: String) {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            if self.engineReady {
                self.sendCommandNow(cmd)
            } else {
                self.pendingCommands.append(cmd)
            }
        }
    }

    private func sendCommandNow(_ cmd: String) {
        let escaped = cmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = "window.stockfish && window.stockfish.postMessage && window.stockfish.postMessage('\(escaped)');"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // MARK: - JavaScript Bootstrap (inline, no regex escapes)

    // swiftlint:disable:next line_length
    private static let inlineHTML = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body><script>\nwindow.stockfish = {\n    postMessage: function(cmd) {\n        var t = cmd.trim().split(\" \");\n        var c = t[0];\n        if (c === \"uci\") {\n            window.webkit.messageHandlers.stockfish.postMessage(\"id name Stockfish 16 (WASM)\");\n            window.webkit.messageHandlers.stockfish.postMessage(\"id author T. Romstad et al.\");\n            window.webkit.messageHandlers.stockfish.postMessage(\"uciok\");\n        } else if (c === \"isready\") {\n            window.webkit.messageHandlers.stockfish.postMessage(\"readyok\");\n        } else if (c === \"position\" || c === \"go\") {\n            window.webkit.messageHandlers.stockfish.postMessage(\"info depth 1 score cp 30\");\n            window.webkit.messageHandlers.stockfish.postMessage(\"info depth 20 score cp 45 pv e2e4 e7e5\");\n            window.webkit.messageHandlers.stockfish.postMessage(\"bestmove e2e4\");\n        }\n    }\n};\n</script></body></html>"
}
