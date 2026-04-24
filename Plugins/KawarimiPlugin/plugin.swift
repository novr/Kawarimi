import Foundation
import PackagePlugin

@main
struct KawarimiPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else {
            throw KawarimiPluginError.incompatibleTarget(name: target.name)
        }
        let targetDirURL = swiftTarget.directoryURL
        let outputDirURL = context.pluginWorkDirectoryURL

        let sourceFileURLs = swiftTarget.sourceFiles.map(\.url)
        let inputURL = try OpenAPIDocumentPath.resolve(inKnownFileURLs: sourceFileURLs, targetName: swiftTarget.name)

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

/// Mirrors swift-openapi-generator `PluginUtils.supportedDocFiles` / `findDocument`. Build tool plugins cannot depend on libraries, so this stays in the plugin target.
private enum OpenAPIDocumentPath {
    private static let supportedBasenames: Set<String> = [
        "openapi.yaml", "openapi.yml", "openapi.json",
    ]

    private static var allowedListPhrase: String {
        supportedBasenames.sorted().joined(separator: ", ")
    }

    static func resolve(inKnownFileURLs urls: some Sequence<URL>, targetName: String) throws -> URL {
        let matches = urls.filter { supportedBasenames.contains($0.standardizedFileURL.lastPathComponent) }
        switch matches.count {
        case 0:
            throw KawarimiPluginError.openAPIDocumentMissing(target: targetName, allowed: allowedListPhrase)
        case 1:
            return matches[0]
        default:
            let paths = matches.map(\.path).sorted()
            throw KawarimiPluginError.openAPIDocumentAmbiguous(target: targetName, paths: paths)
        }
    }
}

enum KawarimiPluginError: Error, CustomStringConvertible {
    case incompatibleTarget(name: String)
    case openAPIDocumentMissing(target: String, allowed: String)
    case openAPIDocumentAmbiguous(target: String, paths: [String])

    var description: String {
        switch self {
        case .incompatibleTarget(let name):
            return "Kawarimi plugin applies only to Swift source modules: \(name)"
        case .openAPIDocumentMissing(let target, let allowed):
            return
                "Target \(target): no OpenAPI document found; place exactly one of \(allowed) in the target (same rule as swift-openapi-generator)."
        case .openAPIDocumentAmbiguous(let target, let paths):
            return "Target \(target): multiple OpenAPI documents found: \(paths.joined(separator: ", "))"
        }
    }
}
