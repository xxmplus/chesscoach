import Foundation
import WebKit
import Combine

// MARK: - StockfishAdapter

/// iOS-compatible UCI chess engine adapter for Stockfish.
/// Uses a hidden WKWebView running Stockfish.js as WebAssembly (no Process API on iOS).
///
/// Bundle structure required:
///   ChessCoachApp/
///     StockfishLoader.html        ← loads stockfish.js + stockfish.wasm.js
///     Assets/stockfish/
///       stockfish.js              ← Emscripten JavaScript wrapper (~1.5 MB)
///       stockfish.wasm.js         ← Emscripten WASM loader (~94 KB)
///       stockfish.wasm            ← WebAssembly binary (~546 KB)
///
/// Swift sends UCI commands via: `window.sfCommand('uci')`
/// Engine output arrives via: `window.webkit.messageHandlers.stockfish.postMessage(...)`
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
    private var engineReady = false
    private var pendingCommands: [String] = []

    // MARK: - WKScriptMessageHandler

    /// Receives messages from the JavaScript engine bridge.
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
        let subject = PassthroughSubject<EngineLine, Never>()
        analysisSubject = subject

        engineQueue.async { [weak self] in
            guard let self = self else { return }
            self.analysisSubject = subject
            self.currentDepth = depth ?? 20

            self.sendCommand("position fen \(fen)")
            var goCmd = "go depth \(self.currentDepth)"
            if let t = timeout {
                goCmd = "go movetime \(Int(t * 1000))"
            }
            self.sendCommand(goCmd)

            // Auto-timeout so we don't leak subscribers
            if let t = timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + t + 2) { [weak self] in
                    self?.stopAnalysisInternal()
                    subject.send(completion: .finished)
                }
            }
        }

        return subject
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

            // Load the bundled StockfishLoader.html
            // It loads stockfish.js + stockfish.wasm from Assets/stockfish/
            if let htmlURL = Bundle.main.url(forResource: "StockfishLoader", withExtension: "html") {
                // Allow read access to the Assets/stockfish/ directory for WASM loading
                let assetsURL = Bundle.main.resourceURL!
                wv.loadFileURL(htmlURL, allowingReadAccessTo: assetsURL)
            } else {
                // Fallback to inline HTML (compile-test only — no real engine)
                wv.loadHTMLString(Self.inlineHTML, baseURL: nil)
            }

            // Give WASM time to initialize, then send uci
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.sendCommand("uci")
            }
        }
    }

    private func handleEngineOutput(_ line: String) {
        engineQueue.async { [weak self] in
            self?.handleEngineOutputOnQueue(line)
        }
    }

#if DEBUG
    func test_handleEngineOutput(_ line: String) {
        handleEngineOutputOnQueue(line)
    }
#endif

    private func handleEngineOutputOnQueue(_ line: String) {
        // The HTML bridge signals engine readiness via this marker
        if line == "stockfish:ready" {
            engineReady = true
            isAvailable = true
            pendingContinuation?.resume()
            pendingContinuation = nil
            let commands = pendingCommands
            pendingCommands.removeAll()
            commands.forEach(sendCommandNow)
            return
        }

        // UCI responses
        if line == "uciok" {
            return
        }
        if line == "readyok" {
            return
        }

        if line.hasPrefix("bestmove") {
            let tokens = line.split(separator: " ").map(String.init)
            lastBestMove = tokens.count >= 2 ? tokens[1] : nil
            return
        }

        // Parse info lines: depth, score, pv
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

    /// Sends a UCI command to the engine via JavaScript bridge.
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

    /// Dispatches command to the WKWebView JavaScript context.
    /// Uses window.sfCommand() which is exposed by StockfishLoader.html.
    private func sendCommandNow(_ cmd: String) {
        // Escape for JavaScript string embedding
        let escaped = cmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")

        // Use the sfCommand bridge exposed by StockfishLoader.html
        let js = "if (window.sfCommand) { window.sfCommand('\(escaped)'); } else { console.warn('sfCommand not ready'); }"

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: { _, error in
                if let error = error {
                    print("[StockfishAdapter] evaluateJavaScript error: \(error)")
                }
            })
        }
    }

    // MARK: - Inline HTML Fallback (compile-test stub, no real engine)

    /// Minimal fallback HTML used only when the real StockfishLoader.html
    /// is not bundled. This stub responds to UCI commands with canned output
    /// so the app can compile and render the UI without the WASM engine.
    private static let inlineHTML = """
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Stockfish</title></head>
<body>
<script>
(function () {
    var handler = window.webkit && window.webkit.messageHandlers
                  && window.webkit.messageHandlers.stockfish;
    function sendToSwift(msg) { if (handler) handler.postMessage(msg); }
    window.sfCommand = function (cmd) {
        var tokens = cmd.trim().split(/\\s+/);
        var c = tokens[0];
        if (c === "uci") {
            sendToSwift("id name Stockfish 16 (stub)");
            sendToSwift("id author T. Romstad et al.");
            sendToSwift("uciok");
            sendToSwift("stockfish:ready");
        } else if (c === "isready") {
            sendToSwift("readyok");
        } else if (c === "quit") {
            // no-op
        } else if (c === "position" || c === "go") {
            // Stub bestmove + a few info lines for UI testing
            sendToSwift("info depth 1 score cp 30 pv e2e4");
            sendToSwift("info depth 10 score cp 42 pv e2e4 e7e5 g1f3");
            sendToSwift("bestmove e2e4");
        }
    };
})();
</script>
</body>
</html>
"""
}
