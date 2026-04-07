import PackagePlugin
import Foundation

@main
struct KawarimiPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else {
            throw KawarimiPluginError.incompatibleTarget(name: target.name)
        }
        // Same convention as swift-openapi-generator: `openapi.yaml` at the Swift target root.
        let targetDirURL = swiftTarget.directoryURL
        let inputURL = targetDirURL.appendingPathComponent("openapi.yaml")
        let outputDirURL = context.pluginWorkDirectoryURL

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw KawarimiPluginError.openAPINotFound(target: target.name, path: inputURL.path)
        }

        let outputNames = ["Kawarimi.swift", "KawarimiHandler.swift", "KawarimiSpec.swift"]
        let outputFiles = outputNames.map { outputDirURL.appendingPathComponent($0) }
        let arguments = [inputURL.path, outputDirURL.path]

        var inputFiles: [URL] = [inputURL]
        let configYAML = targetDirURL.appendingPathComponent("openapi-generator-config.yaml")
        let configYML = targetDirURL.appendingPathComponent("openapi-generator-config.yml")
        if FileManager.default.fileExists(atPath: configYAML.path) {
            inputFiles.append(configYAML)
        }
        if FileManager.default.fileExists(atPath: configYML.path) {
            inputFiles.append(configYML)
        }
        let kawarimiGenYAML = targetDirURL.appendingPathComponent("kawarimi-generator-config.yaml")
        let kawarimiGenYML = targetDirURL.appendingPathComponent("kawarimi-generator-config.yml")
        if FileManager.default.fileExists(atPath: kawarimiGenYAML.path) {
            inputFiles.append(kawarimiGenYAML)
        }
        if FileManager.default.fileExists(atPath: kawarimiGenYML.path) {
            inputFiles.append(kawarimiGenYML)
        }

        let tool = try context.tool(named: "Kawarimi")
        return [
            .buildCommand(
                displayName: "Kawarimi: Generate Mock and Handler from OpenAPI",
                executable: tool.url,
                arguments: arguments,
                inputFiles: inputFiles,
                outputFiles: outputFiles
            ),
        ]
    }
}

enum KawarimiPluginError: Error, CustomStringConvertible {
    case incompatibleTarget(name: String)
    case openAPINotFound(target: String, path: String)

    var description: String {
        switch self {
        case .incompatibleTarget(let name):
            return "Kawarimi plugin applies only to Swift source modules: \(name)"
        case .openAPINotFound(let target, let path):
            return "Target \(target): openapi.yaml not found: \(path)"
        }
    }
}
