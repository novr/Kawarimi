import Foundation
import Testing

@Test func cliGeneratesSwiftFromOpenAPI() throws {
    let openapiURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../KawarimiCoreTests/Fixtures/openapi.yaml")
        .standardizedFileURL
    guard FileManager.default.fileExists(atPath: openapiURL.path) else {
        Issue.record("Shared openapi.yaml not found: \(openapiURL.path)")
        return
    }
    let openapiPath = openapiURL.path
    let packageRoot = resolvePackageRoot()
    let outputDirURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("KawarimiTests-\(UUID().uuidString)")
    let outputDirPath = outputDirURL.path
    try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDirURL) }

    guard let kawarimiURL = findKawarimiExecutable(packageRoot: packageRoot) else {
        Issue.record("Kawarimi executable not found. Run swift build at the package root, then swift test.")
        return
    }

    let process = Process()
    process.executableURL = kawarimiURL
    process.arguments = [openapiPath, outputDirPath]
    process.currentDirectoryURL = packageRoot
    let stderrPipe = Pipe()
    process.standardError = stderrPipe
    try process.run()
    process.waitUntilExit()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

    #expect(process.terminationStatus == 0, "Kawarimi should exit 0 (stderr: \(stderrStr))")

    let kawarimiURLOut = outputDirURL.appendingPathComponent("Kawarimi.swift")
    let handlerURL = outputDirURL.appendingPathComponent("KawarimiHandler.swift")
    let specURL = outputDirURL.appendingPathComponent("KawarimiSpec.swift")

    #expect(FileManager.default.fileExists(atPath: kawarimiURLOut.path), "Kawarimi.swift should be emitted")
    #expect(FileManager.default.fileExists(atPath: handlerURL.path), "KawarimiHandler.swift should be emitted")
    #expect(FileManager.default.fileExists(atPath: specURL.path), "KawarimiSpec.swift should be emitted")

    let kawarimiGenerated = try String(contentsOf: kawarimiURLOut, encoding: .utf8)
    #expect(kawarimiGenerated.contains("public struct Kawarimi"), "Kawarimi.swift should contain ClientTransport type")
    #expect(kawarimiGenerated.contains("ClientTransport"))
    #expect(kawarimiGenerated.contains("case \"getGreeting\""), "case for openapi operationId getGreeting")
    #expect(kawarimiGenerated.contains("case \"listItems\""), "cases for multiple operations")
    #expect(kawarimiGenerated.contains("HTTPResponse(status: .ok)"))
    #expect(kawarimiGenerated.contains("import OpenAPIRuntime"))
    #expect(kawarimiGenerated.contains("import HTTPTypes"))

    let handlerGenerated = try String(contentsOf: handlerURL, encoding: .utf8)
    #expect(handlerGenerated.contains("public struct KawarimiHandler"), "KawarimiHandler.swift should contain type name")
    #expect(handlerGenerated.contains("APIProtocol"))
    #expect(handlerGenerated.contains("public var onGetGreeting:"), "witness on… property")
    #expect(handlerGenerated.contains("try await onGetGreeting(input)"))
    #expect(handlerGenerated.contains("getGreeting"), "method for operationId getGreeting")
    #expect(handlerGenerated.contains("deleteItem"), "DELETE 204 operation in handler")
}

@Test func cliGeneratesSwiftFromOpenAPIJSON() throws {
    let openapiURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../KawarimiCoreTests/Fixtures/openapi.json")
        .standardizedFileURL
    guard FileManager.default.fileExists(atPath: openapiURL.path) else {
        Issue.record("Shared openapi.json not found: \(openapiURL.path)")
        return
    }
    let openapiPath = openapiURL.path
    let packageRoot = resolvePackageRoot()
    let outputDirURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("KawarimiTests-json-\(UUID().uuidString)")
    let outputDirPath = outputDirURL.path
    try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDirURL) }

    guard let kawarimiURL = findKawarimiExecutable(packageRoot: packageRoot) else {
        Issue.record("Kawarimi executable not found. Run swift build at the package root, then swift test.")
        return
    }

    let process = Process()
    process.executableURL = kawarimiURL
    process.arguments = [openapiPath, outputDirPath]
    process.currentDirectoryURL = packageRoot
    let stderrPipe = Pipe()
    process.standardError = stderrPipe
    try process.run()
    process.waitUntilExit()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

    #expect(process.terminationStatus == 0, "Kawarimi should exit 0 (stderr: \(stderrStr))")

    let kawarimiURLOut = outputDirURL.appendingPathComponent("Kawarimi.swift")
    let handlerURL = outputDirURL.appendingPathComponent("KawarimiHandler.swift")
    let specURL = outputDirURL.appendingPathComponent("KawarimiSpec.swift")

    #expect(FileManager.default.fileExists(atPath: kawarimiURLOut.path))
    #expect(FileManager.default.fileExists(atPath: handlerURL.path))
    #expect(FileManager.default.fileExists(atPath: specURL.path))

    let kawarimiGenerated = try String(contentsOf: kawarimiURLOut, encoding: .utf8)
    #expect(kawarimiGenerated.contains("case \"getGreeting\""))
    #expect(kawarimiGenerated.contains("case \"listItems\""))

    let handlerGenerated = try String(contentsOf: handlerURL, encoding: .utf8)
    #expect(handlerGenerated.contains("public var onGetGreeting:"))
    #expect(handlerGenerated.contains("deleteItem"))
}

@Test func cliPartialGenerationSkipsHandler() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-partial-gen-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    try """
    openapi: 3.0.3
    info:
      title: T
      version: '1'
    paths:
      /x:
        get:
          operationId: getX
          responses:
            '200':
              description: ok
              content:
                application/json:
                  schema:
                    type: object
    """.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    try """
    generate:
      - types
      - client
    namingStrategy: defensive
    accessModifier: public
    """.write(toFile: tmp.appendingPathComponent("openapi-generator-config.yaml").path, atomically: true, encoding: .utf8)
    try """
    generateKawarimi: true
    generateHandler: false
    generateSpec: true
    """.write(toFile: tmp.appendingPathComponent("kawarimi-generator-config.yaml").path, atomically: true, encoding: .utf8)

    let packageRoot = resolvePackageRoot()
    let outputDirURL = tmp.appendingPathComponent("out")
    try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    let outputDirPath = outputDirURL.path

    guard let kawarimiURL = findKawarimiExecutable(packageRoot: packageRoot) else {
        Issue.record("Kawarimi executable not found. Run swift build at the package root, then swift test.")
        return
    }

    let process = Process()
    process.executableURL = kawarimiURL
    process.arguments = [openAPIPath, outputDirPath]
    process.currentDirectoryURL = packageRoot
    try process.run()
    process.waitUntilExit()

    #expect(process.terminationStatus == 0)
    #expect(FileManager.default.fileExists(atPath: outputDirURL.appendingPathComponent("Kawarimi.swift").path))
    #expect(!FileManager.default.fileExists(atPath: outputDirURL.appendingPathComponent("KawarimiHandler.swift").path))
    #expect(FileManager.default.fileExists(atPath: outputDirURL.appendingPathComponent("KawarimiSpec.swift").path))
}

@Test func cliWarnsWhenKawarimiGeneratorConfigYamlIsInvalid() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-invalid-kw-cfg-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    try """
    openapi: 3.0.3
    info:
      title: T
      version: '1'
    paths:
      /x:
        get:
          operationId: getX
          responses:
            '200':
              description: ok
              content:
                application/json:
                  schema:
                    type: object
    """.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    try """
    generate:
      - types
      - client
    namingStrategy: defensive
    accessModifier: public
    """.write(toFile: tmp.appendingPathComponent("openapi-generator-config.yaml").path, atomically: true, encoding: .utf8)
    try "{ not: [ valid yaml".write(toFile: tmp.appendingPathComponent("kawarimi-generator-config.yaml").path, atomically: true, encoding: .utf8)

    let packageRoot = resolvePackageRoot()
    let outputDirURL = tmp.appendingPathComponent("out")
    try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    let outputDirPath = outputDirURL.path

    guard let kawarimiURL = findKawarimiExecutable(packageRoot: packageRoot) else {
        Issue.record("Kawarimi executable not found. Run swift build at the package root, then swift test.")
        return
    }

    let process = Process()
    process.executableURL = kawarimiURL
    process.arguments = [openAPIPath, outputDirPath]
    process.currentDirectoryURL = packageRoot
    let stderrPipe = Pipe()
    process.standardError = stderrPipe
    try process.run()
    process.waitUntilExit()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

    #expect(process.terminationStatus == 0, "stderr: \(stderrStr)")
    #expect(stderrStr.contains("Kawarimi warning: invalid kawarimi-generator-config YAML"))
    #expect(stderrStr.contains("kawarimi-generator-config.yaml"))
    #expect(FileManager.default.fileExists(atPath: outputDirURL.appendingPathComponent("Kawarimi.swift").path))
}

@Test func cliPrintsVersion() throws {
    let packageRoot = resolvePackageRoot()
    guard let expectedVersion = buildInfoVersion(packageRoot: packageRoot) else {
        Issue.record("Could not read BuildInfo.version from Sources/Kawarimi/Generated.swift")
        return
    }
    guard let kawarimiURL = findKawarimiExecutable(packageRoot: packageRoot) else {
        Issue.record("Kawarimi executable not found. Run swift build at the package root, then swift test.")
        return
    }

    let result = try runKawarimiCLI(executable: kawarimiURL, arguments: ["--version"], packageRoot: packageRoot)
    #expect(result.exitCode == 0, "stderr: \(result.stderr)")
    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == expectedVersion)
}

@Test func cliPrintsHelp() throws {
    let packageRoot = resolvePackageRoot()
    guard let kawarimiURL = findKawarimiExecutable(packageRoot: packageRoot) else {
        Issue.record("Kawarimi executable not found. Run swift build at the package root, then swift test.")
        return
    }

    for flag in ["--help", "-h"] {
        let result = try runKawarimiCLI(executable: kawarimiURL, arguments: [flag], packageRoot: packageRoot)
        #expect(result.exitCode == 0, "\(flag) stderr: \(result.stderr)")
        #expect(result.stdout.contains("openapi"))
        #expect(result.stdout.contains("output"))
    }
}

@Test func cliRejectsUnknownOption() throws {
    let packageRoot = resolvePackageRoot()
    guard let kawarimiURL = findKawarimiExecutable(packageRoot: packageRoot) else {
        Issue.record("Kawarimi executable not found. Run swift build at the package root, then swift test.")
        return
    }

    let result = try runKawarimiCLI(
        executable: kawarimiURL,
        arguments: ["--not-a-real-flag", "/tmp/openapi.yaml", "/tmp/out"],
        packageRoot: packageRoot
    )
    #expect(result.exitCode != 0)
    let combined = result.stdout + result.stderr
    #expect(combined.contains("Unknown option"))
}

private func resolvePackageRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func findKawarimiExecutable(packageRoot: URL) -> URL? {
    let fm = FileManager.default
    if let binPath = runSwiftBuildShowBinPath(packageRoot: packageRoot), !binPath.isEmpty {
        let url = URL(fileURLWithPath: binPath).appendingPathComponent("Kawarimi")
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
                    .appendingPathComponent("Kawarimi")
            )
        }
    }
    return candidates.first { fm.fileExists(atPath: $0.path) }
}

private struct KawarimiCLIResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private func buildInfoVersion(packageRoot: URL) -> String? {
    let generatedURL = packageRoot.appendingPathComponent("Sources/Kawarimi/Generated.swift")
    guard let text = try? String(contentsOf: generatedURL, encoding: .utf8) else { return nil }
    for line in text.split(whereSeparator: \.isNewline) {
        let trimmed = String(line).trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("static let version") else { continue }
        let parts = trimmed.split(separator: "\"", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { continue }
        return String(parts[1])
    }
    return nil
}

private func runKawarimiCLI(executable: URL, arguments: [String], packageRoot: URL) throws -> KawarimiCLIResult {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = packageRoot
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    try process.run()
    process.waitUntilExit()
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    return KawarimiCLIResult(
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
