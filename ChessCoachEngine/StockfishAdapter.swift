import Foundation
import Combine

// MARK: - StockfishAdapter

/// UCI chess engine adapter for Stockfish (and compatible NNUE engines).
/// Communicates via stdin/stdout using the UCI protocol.
public final class StockfishAdapter: ChessEngine, @unchecked Sendable {
    public let displayName = "Stockfish"
    public private(set) var isAvailable = false

    private var process: Process?
    private let processQueue = DispatchQueue(label: "com.chesscoach.stockfish.process")
    private let outputSubject = PassthroughSubject<String, Never>()
    private var analysisCancellable: AnyCancellable?
    private var bestMoveCancellable: AnyCancellable?
    private var currentDepth: Int?
    private var currentTimeout: TimeInterval?
    private var analysisTimer: Timer?

    public private(set) var lastBestMove: String?

    public init() {}

    // MARK: - Initialize

    public func initialize() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            processQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EngineError.notAvailable)
                    return
                }

                let enginePath = Self.engineBinaryPath()
                let fileManager = FileManager.default

                // Download if not present
                if !fileManager.fileExists(atPath: enginePath) {
                    do {
                        try Self.downloadEngine(to: enginePath)
                    } catch {
                        continuation.resume(throwing: EngineError.initializationFailed("Download failed: \(error.localizedDescription)"))
                        return
                    }
                }

                self.launchProcess()
                self.isAvailable = self.process != nil
                if self.isAvailable {
                    self.sendCommand("uci")
                    // Read initial uciok
                    var uciok = false
                    let sub = self.outputSubject.sink { line in
                        if line == "uciok" { uciok = true }
                    }
                    // Timeout after 5 seconds
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        sub.cancel()
                        if !uciok {
                            continuation.resume(throwing: EngineError.initializationFailed("uciok not received"))
                        }
                    }
                } else {
                    continuation.resume(throwing: EngineError.notAvailable)
                }
            }
        }
    }

    // MARK: - Analysis

    public func startAnalysis(fen: String, depth: Int?, timeout: TimeInterval?) -> AnyPublisher<EngineLine, Never> {
        stopAnalysis()

        currentDepth = depth ?? 30
        currentTimeout = timeout

        let subject = PassthroughSubject<EngineLine, Never>()

        analysisCancellable = outputSubject
            .compactMap { line -> EngineLine? in
                guard let parsed = UCIParser.parseInfoLine(line) else { return nil }
                return EngineLine(
                    depth: parsed.depth,
                    score: parsed.score,
                    moves: parsed.moves,
                    pv: parsed.pv
                )
            }
            .filter { [weak self] line in
                guard let maxDepth = self?.currentDepth else { return true }
                return line.depth <= maxDepth
            }
            .sink { line in
                subject.send(line)
            }

        bestMoveCancellable = outputSubject
            .filter { $0.hasPrefix("bestmove") }
            .sink { [weak self] line in
                let (move, _) = UCIParser.parseBestMove(line)
                self?.lastBestMove = move
                self?.stopAnalysis()
                subject.send(completion: .finished)
            }

        sendCommand("position fen \(fen)")
        var cmd = "go depth \(currentDepth ?? 30)"
        if let t = timeout {
            cmd = "go movetime \(Int(t * 1000))"
        }
        sendCommand(cmd)

        // Timeout timer
        if let t = timeout {
            analysisTimer = Timer.scheduledTimer(withTimeInterval: t + 0.5, repeats: false) { [weak self] _ in
                self?.stopAnalysis()
                subject.send(completion: .finished)
            }
        }

        return subject.eraseToAnyPublisher()
    }

    public func stopAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        analysisCancellable?.cancel()
        analysisCancellable = nil
        bestMoveCancellable?.cancel()
        bestMoveCancellable = nil
        sendCommand("stop")
    }

    public func shutdown() {
        stopAnalysis()
        processQueue.async { [weak self] in
            self?.process?.terminate()
            self?.process = nil
            self?.isAvailable = false
        }
    }

    // MARK: - Private

    private func sendCommand(_ cmd: String) {
        processQueue.async { [weak self] in
            guard let self = self,
                  let process = self.process,
                  let inputPipe = process.standardInput as? Pipe else { return }
            let data = (cmd + "\n").data(using: .utf8)!
            inputPipe.fileHandleForWriting.write(data)
        }
    }

    private func launchProcess() {
        let enginePath = Self.engineBinaryPath()
        guard FileManager.default.fileExists(atPath: enginePath) else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: enginePath)
        p.arguments = []

        let outputPipe = Pipe()
        p.standardOutput = outputPipe
        p.standardError = FileHandle.nullDevice

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let str = String(data: data, encoding: .utf8) else { return }
            let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines {
                self?.outputSubject.send(line)
            }
        }

        do {
            try p.run()
            process = p
        } catch {
            print("StockfishAdapter: failed to launch: \(error)")
        }
    }

    // MARK: - Engine Binary Management

    /// Path where the engine binary is stored
    private static func engineBinaryPath() -> String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return "\(docs)/stockfish"
    }

    /// Download the Stockfish static binary
    private static func downloadEngine(to destination: String) throws {
        // Stockfish 16 official static binary for Apple Silicon
        let url = URL(string: "https://stockfishchess.org/files/stockfish-16-64bit.zip")!
        let tmpZip = NSTemporaryDirectory() + "/stockfish.zip"

        let data = try Data(contentsOf: url)
        try data.write(to: URL(fileURLWithPath: tmpZip))

        // Unzip
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-o", tmpZip, "-d", URL(fileURLWithPath: NSTemporaryDirectory()).path]
        try task.run()
        task.waitUntilExit()

        // Find the binary in the temp directory
        let tmpDir = NSTemporaryDirectory()
        var foundBin: String?
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: tmpDir) {
            for item in contents where item.contains("stockfish") && !item.hasSuffix(".zip") {
                foundBin = item
                break
            }
        }

        let src: String
        if let bin = foundBin {
            src = tmpDir + "/" + bin
        } else {
            // Fallback: look in /usr/local/bin
            src = "/usr/local/bin/stockfish"
        }

        if FileManager.default.fileExists(atPath: src) {
            try FileManager.default.moveItem(atPath: src, toPath: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination)
        }

        try? FileManager.default.removeItem(atPath: tmpZip)
    }
}
