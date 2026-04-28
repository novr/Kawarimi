import Foundation
import Testing
@testable import Kawarimi

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

@Test func writeIfChangedSkipsWriteWhenContentIsSame() throws {
    let outputDirURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("KawarimiTests-writer-same-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDirURL) }

    let targetURL = outputDirURL.appendingPathComponent("Kawarimi.swift")
    let content = "public struct Kawarimi {}\n"
    try content.write(to: targetURL, atomically: true, encoding: .utf8)

    let didWrite = try GeneratedFileWriter.writeIfChanged(content, to: targetURL)
    let written = try String(contentsOf: targetURL, encoding: .utf8)

    #expect(didWrite == false, "writeIfChanged should skip writing when content is unchanged")
    #expect(written == content, "file content should remain unchanged")
}

@Test func writeIfChangedOverwritesWhenContentDiffers() throws {
    let outputDirURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("KawarimiTests-writer-diff-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDirURL) }

    let targetURL = outputDirURL.appendingPathComponent("Kawarimi.swift")
    let before = "before\n"
    let after = "after\n"
    try before.write(to: targetURL, atomically: true, encoding: .utf8)

    let didWrite = try GeneratedFileWriter.writeIfChanged(after, to: targetURL)
    let written = try String(contentsOf: targetURL, encoding: .utf8)

    #expect(didWrite == true, "writeIfChanged should write when content differs")
    #expect(written == after, "file should be overwritten with new content")
}

private func resolvePackageRoot() -> URL {
    var root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    if root.lastPathComponent != "Kawarimi" {
        root = root.appendingPathComponent("Kawarimi")
    }
    return root
}

private func findKawarimiExecutable(packageRoot: URL) -> URL? {
    let fm = FileManager.default
    let candidates: [URL] = [
        packageRoot.appendingPathComponent(".build").appendingPathComponent("arm64-apple-macosx").appendingPathComponent("debug").appendingPathComponent("Kawarimi"),
        packageRoot.appendingPathComponent(".build").appendingPathComponent("arm64e-apple-macosx").appendingPathComponent("debug").appendingPathComponent("Kawarimi"),
        packageRoot.appendingPathComponent(".build").appendingPathComponent("x86_64-apple-macosx").appendingPathComponent("debug").appendingPathComponent("Kawarimi"),
        packageRoot.deletingLastPathComponent().appendingPathComponent(".build").appendingPathComponent("arm64-apple-macosx").appendingPathComponent("debug").appendingPathComponent("Kawarimi"),
        packageRoot.deletingLastPathComponent().appendingPathComponent(".build").appendingPathComponent("arm64e-apple-macosx").appendingPathComponent("debug").appendingPathComponent("Kawarimi"),
        packageRoot.deletingLastPathComponent().appendingPathComponent(".build").appendingPathComponent("x86_64-apple-macosx").appendingPathComponent("debug").appendingPathComponent("Kawarimi"),
    ]
    for url in candidates where fm.fileExists(atPath: url.path) {
        return url
    }
    if let binPath = runSwiftBuildShowBinPath(packageRoot: packageRoot), !binPath.isEmpty {
        let url = URL(fileURLWithPath: binPath).appendingPathComponent("Kawarimi")
        if fm.fileExists(atPath: url.path) { return url }
    }
    return nil
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
