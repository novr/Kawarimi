#if os(macOS) || os(Linux)
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Spins up a `DemoServer` subprocess; learns the listen URL from a ready file written at boot.
struct DemoServerHarness {
    private(set) var baseURL: URL
    var kawarimiBaseURL: URL { baseURL.appending(path: "__kawarimi") }

    private let process: Process
    private let configDir: URL
    private let listenReadyFile: URL
    private let stderrMonitor: StderrMonitor

    static func start(packageRoot: URL, timeout: TimeInterval = 45) async throws -> DemoServerHarness {
        guard let executable = findDemoServerExecutable(packageRoot: packageRoot) else {
            throw HarnessError.demoServerNotBuilt(
                "DemoServer executable not found. Run `swift build --product DemoServer` in Example/DemoPackage."
            )
        }

        let configDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DemoServerE2E-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configPath = configDir.appendingPathComponent("kawarimi.json")
        try Data("{\"overrides\":[]}".utf8).write(to: configPath)
        let listenReadyFile = configDir.appendingPathComponent("listen-ready.txt")

        let stderrPipe = Pipe()
        let stderrMonitor = StderrMonitor(pipe: stderrPipe)
        let process = Process()
        process.executableURL = executable
        process.currentDirectoryURL = packageRoot
        var environment = ProcessInfo.processInfo.environment
        environment["HOST"] = "127.0.0.1"
        environment["PORT"] = "0"
        environment["KAWARIMI_CONFIG"] = configPath.path
        environment["KAWARIMI_LISTEN_READY_FILE"] = listenReadyFile.path
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe
        try process.run()

        var harness = DemoServerHarness(
            baseURL: URL(string: "http://127.0.0.1:0")!,
            process: process,
            configDir: configDir,
            listenReadyFile: listenReadyFile,
            stderrMonitor: stderrMonitor
        )
        try await harness.waitUntilReady(timeout: timeout)
        return harness
    }

    func resetOverrides() async throws {
        let (response, _) = try await DemoServerHTTP.postJSON(
            kawarimiBaseURL.appending(path: "reset"),
            body: Data("{}".utf8)
        )
        guard response.statusCode == 200 else {
            throw HarnessError.unexpectedHTTPStatus(
                response.statusCode,
                url: kawarimiBaseURL.appending(path: "reset"),
                stderr: stderrMonitor.snapshot()
            )
        }
    }

    func shutdown() {
        stderrMonitor.stop()
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        _ = stderrMonitor.drain()
        try? FileManager.default.removeItem(at: configDir)
    }

    private init(
        baseURL: URL,
        process: Process,
        configDir: URL,
        listenReadyFile: URL,
        stderrMonitor: StderrMonitor
    ) {
        self.baseURL = baseURL
        self.process = process
        self.configDir = configDir
        self.listenReadyFile = listenReadyFile
        self.stderrMonitor = stderrMonitor
    }

    private mutating func waitUntilReady(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !process.isRunning {
                throw HarnessError.serverExitedEarly(
                    process.terminationStatus,
                    stderr: stderrMonitor.snapshot()
                )
            }

            if let origin = Self.readListenOrigin(from: listenReadyFile) {
                let apiBase = DemoServerE2EPaths.apiBaseURL(origin: origin)
                var request = URLRequest(url: apiBase.appending(path: "greet"))
                request.httpMethod = "GET"
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        baseURL = apiBase
                        return
                    }
                } catch {
                    // Server still starting.
                }
            }

            try await Task.sleep(for: .milliseconds(100))
        }
        let hint = "\(DemoServerE2EPaths.greetPath) on listen-ready file"
        throw HarnessError.readyTimeout(hint, stderr: stderrMonitor.snapshot())
    }

    private static func readListenOrigin(from fileURL: URL) -> URL? {
        guard let data = try? Data(contentsOf: fileURL),
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init),
            !firstLine.isEmpty
        else {
            return nil
        }
        return URL(string: firstLine)
    }
}

private final class StderrMonitor: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var buffer = Data()

    init(pipe: Pipe) {
        handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] source in
            guard let self else { return }
            let chunk = source.availableData
            guard !chunk.isEmpty else { return }
            self.lock.lock()
            self.buffer.append(chunk)
            self.lock.unlock()
        }
    }

    func stop() {
        handle.readabilityHandler = nil
    }

    func snapshot(maxCharacters: Int = 8_000) -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let text = String(data: buffer, encoding: .utf8), !text.isEmpty else { return "" }
        guard text.count > maxCharacters else { return text }
        return "…(truncated)\n" + String(text.suffix(maxCharacters))
    }

    func drain() -> String {
        stop()
        lock.lock()
        defer { lock.unlock() }
        let pending = handle.availableData
        if !pending.isEmpty {
            buffer.append(pending)
        }
        return String(data: buffer, encoding: .utf8) ?? ""
    }
}

enum HarnessError: Error, CustomStringConvertible {
    case demoServerNotBuilt(String)
    case serverExitedEarly(Int32, stderr: String)
    case readyTimeout(String, stderr: String)
    case unexpectedHTTPStatus(Int, url: URL, stderr: String)

    var description: String {
        switch self {
        case .demoServerNotBuilt(let message):
            message
        case .serverExitedEarly(let code, let stderr):
            HarnessError.describe(
                "DemoServer exited before ready (status \(code))",
                stderr: stderr
            )
        case .readyTimeout(let url, let stderr):
            HarnessError.describe("Timed out waiting for DemoServer at \(url)", stderr: stderr)
        case .unexpectedHTTPStatus(let status, let url, let stderr):
            HarnessError.describe("Unexpected HTTP \(status) from \(url)", stderr: stderr)
        }
    }

    private static func describe(_ headline: String, stderr: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return headline }
        return headline + "\n--- DemoServer stderr ---\n" + trimmed
    }
}

enum DemoServerHTTP {
    static func get(_ url: URL) async throws -> (HTTPURLResponse, Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await data(for: request)
    }

    static func postJSON(_ url: URL, body: Data) async throws -> (HTTPURLResponse, Data) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await data(for: request)
    }

    private static func data(for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            let url = request.url?.absoluteString ?? "about:blank"
            throw HarnessError.readyTimeout("Non-HTTP response from \(url)", stderr: "")
        }
        return (http, data)
    }
}

private func findDemoServerExecutable(packageRoot: URL) -> URL? {
    let fm = FileManager.default
    let triples = [
        "arm64-apple-macosx", "arm64e-apple-macosx", "x86_64-apple-macosx",
        "aarch64-unknown-linux-gnu", "x86_64-unknown-linux-gnu",
    ]
    var candidates: [URL] = []
    for triple in triples {
        candidates.append(
            packageRoot
                .appendingPathComponent(".build")
                .appendingPathComponent(triple)
                .appendingPathComponent("debug")
                .appendingPathComponent("DemoServer")
        )
    }
    if let binPath = runSwiftBuildShowBinPath(packageRoot: packageRoot), !binPath.isEmpty {
        candidates.append(URL(fileURLWithPath: binPath).appendingPathComponent("DemoServer"))
    }
    return candidates.first { fm.fileExists(atPath: $0.path) }
}

private func runSwiftBuildShowBinPath(packageRoot: URL) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "build", "--package-path", packageRoot.path, "--show-bin-path"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

func resolveDemoPackageRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
#endif
