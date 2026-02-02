import PackagePlugin
import Foundation

@main
struct KawarimiPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else {
            throw KawarimiPluginError.incompatibleTarget(name: target.name)
        }
        guard let firstSource = swiftTarget.sourceFiles.first else {
            throw KawarimiPluginError.noSourceFiles(target: target.name)
        }
        let targetDirURL = firstSource.url.deletingLastPathComponent()
        let inputURL = targetDirURL.appendingPathComponent("openapi.yaml")
        let outputDirURL = context.pluginWorkDirectoryURL

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw KawarimiPluginError.openAPINotFound(target: target.name, path: inputURL.path)
        }

        let kawarimiConfigURL = targetDirURL.appendingPathComponent("kawarimi.yaml")
        let officialConfigURL = targetDirURL.appendingPathComponent("openapi-generator-config.yaml")
        let (resolvedOutputNames, configPathForTool, inputFileURLs) = resolveOutputsAndInputs(
            targetDirURL: targetDirURL,
            kawarimiConfigURL: kawarimiConfigURL,
            officialConfigURL: officialConfigURL,
            openapiURL: inputURL
        )

        let outputFiles = resolvedOutputNames.map { outputDirURL.appendingPathComponent($0) }
        var arguments = [inputURL.path, outputDirURL.path]
        if let configPathForTool {
            arguments.append(configPathForTool)
        }

        let tool = try context.tool(named: "Kawarimi")
        return [
            .buildCommand(
                displayName: "Kawarimi: Generate API (Types/Client/Server) and Mock from OpenAPI",
                executable: tool.url,
                arguments: arguments,
                inputFiles: inputFileURLs,
                outputFiles: outputFiles
            ),
        ]
    }

    /// config を読んで出力ファイル名リストと入力ファイルリストを決める。outputFiles は generate に合わせ、inputFiles に config を含める。
    private func resolveOutputsAndInputs(
        targetDirURL: URL,
        kawarimiConfigURL: URL,
        officialConfigURL: URL,
        openapiURL: URL
    ) -> (outputNames: [String], configPathForTool: String?, inputFileURLs: [URL]) {
        let fm = FileManager.default
        var inputFileURLs: [URL] = [openapiURL]
        var configPathForTool: String? = nil

        func readGenerate(from path: String) -> [String]? {
            guard let data = fm.contents(atPath: path),
                  let content = String(data: data, encoding: .utf8) else {
                return nil
            }
            return parseGenerateFromYAML(content)
        }

        let list: [String]?
        if fm.fileExists(atPath: kawarimiConfigURL.path) {
            configPathForTool = kawarimiConfigURL.path
            inputFileURLs.append(kawarimiConfigURL)
            list = readGenerate(from: kawarimiConfigURL.path)
        } else if fm.fileExists(atPath: officialConfigURL.path) {
            configPathForTool = officialConfigURL.path
            inputFileURLs.append(officialConfigURL)
            list = readGenerate(from: officialConfigURL.path)
        } else {
            list = nil
        }

        let modeNames: [String]
        if let list, !list.isEmpty {
            modeNames = list.filter { ["types", "client", "server"].contains($0.lowercased()) }
        } else {
            modeNames = ["types", "client", "server"]
        }

        let outputNames: [String] = modeNames.uniquedPreservingOrder().map { name in
            switch name.lowercased() {
            case "types": return "Types.swift"
            case "client": return "Client.swift"
            case "server": return "Server.swift"
            default: return "Types.swift"
            }
        } + ["Kawarimi.swift", "DefaultHandler.swift"]

        return (outputNames, configPathForTool, inputFileURLs)
    }
}

/// YAML から generate 配列だけを簡易パースする（プラグインは Yams に依存できないため）。
private func parseGenerateFromYAML(_ yaml: String) -> [String]? {
    let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false)
    guard let generateLineIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).starts(with: "generate:") }) else {
        return nil
    }
    var values: [String] = []
    for i in (generateLineIndex + 1)..<lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if !trimmed.starts(with: "-") && !trimmed.starts(with: " ") && !trimmed.starts(with: "\t") { break }
        if trimmed.starts(with: "-") {
            let value = trimmed.dropFirst().trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !value.isEmpty { values.append(String(value)) }
        }
    }
    return values.isEmpty ? nil : values
}

private extension Array where Element: Hashable {
    func uniquedPreservingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

enum KawarimiPluginError: Error, CustomStringConvertible {
    case incompatibleTarget(name: String)
    case noSourceFiles(target: String)
    case openAPINotFound(target: String, path: String)

    var description: String {
        switch self {
        case .incompatibleTarget(let name):
            return "Kawarimi プラグインは Swift ソースモジュールにのみ適用できます: \(name)"
        case .noSourceFiles(let target):
            return "ターゲット \(target) にソースファイルがありません"
        case .openAPINotFound(let target, let path):
            return "ターゲット \(target): openapi.yaml が見つかりません: \(path)"
        }
    }
}
