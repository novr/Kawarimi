import Foundation
import Testing

/// プラグインが起動する Kawarimi 実行体と同一の生成結果であることを保証する。
@Test func cliGeneratesSwiftFromOpenAPI() throws {
    let openapiURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../KawarimiCoreTests/Fixtures/openapi.yaml")
        .standardizedFileURL
    guard FileManager.default.fileExists(atPath: openapiURL.path) else {
        Issue.record("共有 openapi.yaml が見つかりません: \(openapiURL.path)")
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
        Issue.record("Kawarimi 実行体が見つかりません。パッケージルートで swift build 後に swift test を実行してください。")
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

    #expect(process.terminationStatus == 0, "Kawarimi が終了コード 0 で終了すること (stderr: \(stderrStr))")

    let kawarimiURLOut = outputDirURL.appendingPathComponent("Kawarimi.swift")
    let handlerURL = outputDirURL.appendingPathComponent("KawarimiHandler.swift")
    let specURL = outputDirURL.appendingPathComponent("KawarimiSpec.swift")

    #expect(FileManager.default.fileExists(atPath: kawarimiURLOut.path), "Kawarimi.swift が出力されること")
    #expect(FileManager.default.fileExists(atPath: handlerURL.path), "KawarimiHandler.swift が出力されること")
    #expect(FileManager.default.fileExists(atPath: specURL.path), "KawarimiSpec.swift が出力されること")

    let kawarimiGenerated = try String(contentsOf: kawarimiURLOut, encoding: .utf8)
    #expect(kawarimiGenerated.contains("public struct Kawarimi"), "Kawarimi.swift に ClientTransport 用の型名が含まれること")
    #expect(kawarimiGenerated.contains("ClientTransport"))
    #expect(kawarimiGenerated.contains("case \"getGreeting\""), "openapi の operationId に対応する case が含まれること")
    #expect(kawarimiGenerated.contains("case \"listItems\""), "複数 operation の case が生成されること")
    #expect(kawarimiGenerated.contains("HTTPResponse(status: .ok)"))
    #expect(kawarimiGenerated.contains("import OpenAPIRuntime"))
    #expect(kawarimiGenerated.contains("import HTTPTypes"))

    let handlerGenerated = try String(contentsOf: handlerURL, encoding: .utf8)
    #expect(handlerGenerated.contains("public struct KawarimiHandler"), "KawarimiHandler.swift に型名が含まれること")
    #expect(handlerGenerated.contains("APIProtocol"))
    #expect(handlerGenerated.contains("public var onGetGreeting:"), "witness 用 on… プロパティが含まれること")
    #expect(handlerGenerated.contains("try await onGetGreeting(input)"))
    #expect(handlerGenerated.contains("getGreeting"), "openapi の operationId に対応するメソッドが含まれること")
    #expect(handlerGenerated.contains("deleteItem"), "DELETE 204 系 operation がハンドラに含まれること")
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
