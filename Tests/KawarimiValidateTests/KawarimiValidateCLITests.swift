import Foundation
import KawarimiCore
import Testing

@Suite("KawarimiValidate CLI")
struct KawarimiValidateCLITests {
    @Test func cliExitsZeroForExampleFixtures() throws {
        let packageRoot = resolvePackageRoot()
        guard let executable = findKawarimiValidateExecutable(packageRoot: packageRoot) else {
            Issue.record("KawarimiValidate executable not found. Run swift build, then swift test.")
            return
        }

        let configPath = packageRoot
            .appendingPathComponent("Example/DemoPackage/kawarimi.json.example")
            .path
        let scenariosPath = packageRoot
            .appendingPathComponent("Example/DemoPackage/kawarimi-scenarios.json")
            .path

        let result = try runCLI(
            executable: executable,
            arguments: ["--config", configPath, "--scenarios", scenariosPath],
            packageRoot: packageRoot
        )
        #expect(result.exitCode == 0, "stderr: \(result.stderr)")
    }

    @Test func cliExitsOneWhenWarningsPresent() throws {
        let packageRoot = resolvePackageRoot()
        guard let executable = findKawarimiValidateExecutable(packageRoot: packageRoot) else {
            Issue.record("KawarimiValidate executable not found. Run swift build, then swift test.")
            return
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json")
        let scenariosPath = dir.appendingPathComponent("kawarimi-scenarios.json")
        try #"{"overrides": []}"#.write(to: configPath, atomically: true, encoding: .utf8)
        try """
        {
          "scenarios": [
            {
              "scenarioId": "login",
              "initial": "start",
              "cases": [
                {
                  "kawarimiId": "start",
                  "rowId": "00000000-0000-0000-0000-000000000099",
                  "endpoint": { "method": "POST", "path": "/api/login" }
                }
              ]
            }
          ]
        }
        """.write(to: scenariosPath, atomically: true, encoding: .utf8)

        let result = try runCLI(
            executable: executable,
            arguments: ["--config", configPath.path, "--scenarios", scenariosPath.path],
            packageRoot: packageRoot
        )
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("rowId"))
    }

    @Test func cliExitsTwoOnInvalidConfigJSON() throws {
        let packageRoot = resolvePackageRoot()
        guard let executable = findKawarimiValidateExecutable(packageRoot: packageRoot) else {
            Issue.record("KawarimiValidate executable not found. Run swift build, then swift test.")
            return
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json")
        try "{ not json".write(to: configPath, atomically: true, encoding: .utf8)

        let result = try runCLI(
            executable: executable,
            arguments: ["--config", configPath.path],
            packageRoot: packageRoot
        )
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Invalid kawarimi.json"))
    }

    @Test func cliExitsTwoOnMissingExplicitScenariosFile() throws {
        let packageRoot = resolvePackageRoot()
        guard let executable = findKawarimiValidateExecutable(packageRoot: packageRoot) else {
            Issue.record("KawarimiValidate executable not found. Run swift build, then swift test.")
            return
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json")
        try #"{"overrides": []}"#.write(to: configPath, atomically: true, encoding: .utf8)
        let missingScenarios = dir.appendingPathComponent("no-such-scenarios.json").path

        let result = try runCLI(
            executable: executable,
            arguments: ["--config", configPath.path, "--scenarios", missingScenarios],
            packageRoot: packageRoot
        )
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Scenarios file not found"))
    }

    @Test func cliExitsTwoWhenScenariosEnvPointsAtMissingFile() throws {
        let packageRoot = resolvePackageRoot()
        guard let executable = findKawarimiValidateExecutable(packageRoot: packageRoot) else {
            Issue.record("KawarimiValidate executable not found. Run swift build, then swift test.")
            return
        }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json")
        try #"{"overrides": []}"#.write(to: configPath, atomically: true, encoding: .utf8)
        let missingScenarios = dir.appendingPathComponent("no-such-scenarios.json").path

        let result = try runCLI(
            executable: executable,
            arguments: ["--config", configPath.path],
            packageRoot: packageRoot,
            environment: [KawarimiScenarioDefaults.environmentKey: missingScenarios]
        )
        #expect(result.exitCode == 2)
        #expect(result.stderr.contains("Scenarios file not found"))
    }
}

private struct CLIResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private func resolvePackageRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func findKawarimiValidateExecutable(packageRoot: URL) -> URL? {
    let fm = FileManager.default
    if let binPath = runSwiftBuildShowBinPath(packageRoot: packageRoot), !binPath.isEmpty {
        let url = URL(fileURLWithPath: binPath).appendingPathComponent("KawarimiValidate")
        if fm.fileExists(atPath: url.path) { return url }
    }
    let macOSTriples = ["arm64-apple-macosx", "arm64e-apple-macosx", "x86_64-apple-macosx"]
    let linuxTriples = ["aarch64-unknown-linux-gnu", "x86_64-unknown-linux-gnu"]
    let roots = [packageRoot, packageRoot.deletingLastPathComponent()]
    var candidates: [URL] = []
    for root in roots {
        for triple in macOSTriples + linuxTriples {
            candidates.append(
                root.appendingPathComponent(".build").appendingPathComponent(triple).appendingPathComponent("debug")
                    .appendingPathComponent("KawarimiValidate")
            )
        }
    }
    return candidates.first { fm.fileExists(atPath: $0.path) }
}

private func runCLI(
    executable: URL,
    arguments: [String],
    packageRoot: URL,
    environment: [String: String]? = nil
) throws -> CLIResult {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = packageRoot
    if let environment {
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env
    }
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    try process.run()
    process.waitUntilExit()
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    return CLIResult(
        exitCode: process.terminationStatus,
        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
        stderr: String(data: stderrData, encoding: .utf8) ?? ""
    )
}

private func runSwiftBuildShowBinPath(packageRoot: URL) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "build", "--package-path", packageRoot.path, "--show-bin-path"]
    process.environment = ProcessInfo.processInfo.environment
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}
