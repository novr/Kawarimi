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

        let outputNames = ["Kawarimi.swift", "KawarimiHandler.swift", "KawarimiSpec.swift"]
        let outputFiles = outputNames.map { outputDirURL.appendingPathComponent($0) }
        let arguments = [inputURL.path, outputDirURL.path]

        let tool = try context.tool(named: "Kawarimi")
        return [
            .buildCommand(
                displayName: "Kawarimi: Generate Mock and Handler from OpenAPI",
                executable: tool.url,
                arguments: arguments,
                inputFiles: [inputURL],
                outputFiles: outputFiles
            ),
        ]
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
