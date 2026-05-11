import Foundation

// MARK: - LLMServerManager

/// Manages the lifecycle of a local llama-server process.
public protocol LLMServerManager: Sendable {
    /// Start the server. Returns the port it is listening on.
    func start(modelPath: String) async throws -> Int

    /// Stop the server.
    func stop() async

    /// Whether the server is currently running.
    var isRunning: Bool { get }
}

// MARK: - ProcessLLMServerManager

/// macOS implementation: launches llama-server as a local subprocess.
/// Conditionally compiled — not available on iOS Simulator or iOS device.
#if os(macOS)
import Foundation

public final class ProcessLLMServerManager: LLMServerManager, @unchecked Sendable {
    private var process: Process?
    private var port: Int = 8080
    private let queue = DispatchQueue(label: "llm.server.manager")

    public var isRunning: Bool {
        queue.sync { process?.isRunning ?? false }
    }

    public func start(modelPath: String) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.modelLoadFailed("Manager deallocated"))
                    return
                }

                let binaryName = "llama-server"
                let paths = [
                    "/opt/homebrew/bin/\(binaryName)",
                    "/usr/local/bin/\(binaryName)",
                    "/opt/homebrew/opt/llama.cpp/bin/\(binaryName)",
                    Bundle.main.path(forAuxiliaryExecutable: binaryName)
                ].compactMap { $0 }

                let binaryPath: String
                if let found = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                    binaryPath = found
                } else {
                    continuation.resume(throwing: LLMError.modelLoadFailed("llama-server not found. Install with: brew install llama.cpp"))
                    return
                }

                let chosenPort = self.findFreePort()
                self.port = chosenPort

                let process = Process()
                process.executableURL = URL(fileURLWithPath: binaryPath)
                process.arguments = [
                    "-m", modelPath,
                    "-c", "2048",
                    "--port", "\(chosenPort)",
                    "-ngl", "99",
                ]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: LLMError.modelLoadFailed("Failed to start: \(error.localizedDescription)"))
                    return
                }

                self.process = process

                Task {
                    var attempts = 0
                    let maxAttempts = 60
                    while attempts < maxAttempts {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if await self.serverIsReady(port: chosenPort) {
                            continuation.resume(returning: chosenPort)
                            return
                        }
                        attempts += 1
                    }
                    continuation.resume(throwing: LLMError.modelLoadFailed("Server did not become ready in time"))
                }
            }
        }
    }

    public func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                self?.process?.terminate()
                self?.process = nil
                continuation.resume()
            }
        }
    }

    private func findFreePort() -> Int {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(sock) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = UInt32(INADDR_LOOPBACK)

        var reuseAddr: Int = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int>.size))

        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var len: socklen_t = socklen_t(MemoryLayout<sockaddr_in>.size)
        getsockname(sock, withUnsafeMutablePointer(to: &addr) { $0 }, &len)
        return Int(ntohs(addr.sin_port))
    }

    private func serverIsReady(port: Int) -> Bool {
        guard let url = URL(string: "http://localhost:\(port)/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        var response: URLResponse?
        _ = try? URLSession.shared.synchronousDataTask(with: request, completionHandler: { _, resp, _ in response = resp }).resume()
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}

extension Bundle {
    func path(forAuxiliaryExecutable name: String) -> String? {
        return executable?.replacingOccurrences(
            of: Bundle.main.bundleIdentifier.map { URL(fileURLWithPath: executable ?? "").deletingLastPathComponent().path } ?? "",
            with: "/Contents/MacOS"
        ).replacingOccurrences(of: "/Contents/MacOS/ChessCoachApp", with: "/Contents/Resources/\(name)")
    }
}
#endif
