import Foundation
import PackagePlugin

@main
struct KawarimiPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else {
            throw KawarimiPluginError.incompatibleTarget(name: target.name)
        }
        let outputDirURL = context.pluginWorkDirectoryURL

        let sourceFileURLs = swiftTarget.sourceFiles.map(\.url)
        let (openAPIURL, generatorConfigURL, kawarimiConfigURL) = try OpenAPIGeneratorStyleTargetFiles.resolve(
            sourceFileURLs: sourceFileURLs,
            targetName: swiftTarget.name
        )

        let outputNames = ["Kawarimi.swift", "KawarimiHandler.swift", "KawarimiSpec.swift"]
        let outputFiles = outputNames.map { outputDirURL.appendingPathComponent($0) }
        let arguments = [openAPIURL.path, outputDirURL.path]

        var inputFiles: [URL] = [openAPIURL, generatorConfigURL]
        if let kawarimiConfigURL {
            inputFiles.append(kawarimiConfigURL)
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

private enum OpenAPIGeneratorStyleTargetFiles {
    private static let supportedDocBasenames: Set<String> = ["openapi.yaml", "openapi.yml", "openapi.json"]
    private static let supportedConfigBasenames: Set<String> = [
        "openapi-generator-config.yaml", "openapi-generator-config.yml",
    ]
    private static let supportedKawarimiConfigBasenames: Set<String> = [
        "kawarimi-generator-config.yaml", "kawarimi-generator-config.yml",
    ]

    static func resolve(sourceFileURLs: [URL], targetName: String) throws -> (
        openAPI: URL,
        generatorConfig: URL,
        kawarimiConfig: URL?
    ) {
        let docs = sourceFileURLs.filter { supportedDocBasenames.contains($0.standardizedFileURL.lastPathComponent) }
        let configs = sourceFileURLs.filter { supportedConfigBasenames.contains($0.standardizedFileURL.lastPathComponent) }
        let kawarimiConfigs = sourceFileURLs.filter {
            supportedKawarimiConfigBasenames.contains($0.standardizedFileURL.lastPathComponent)
        }

        var lines: [String] = []
        switch configs.count {
        case 0:
            lines.append(OpenAPIGeneratorFileErrorMessages.noConfigFileFound(targetName: targetName))
        case 1:
            break
        default:
            lines.append(OpenAPIGeneratorFileErrorMessages.multipleConfigFiles(targetName: targetName, files: configs))
        }
        switch docs.count {
        case 0:
            lines.append(OpenAPIGeneratorFileErrorMessages.noOpenAPIDocument(targetName: targetName))
        case 1:
            break
        default:
            lines.append(OpenAPIGeneratorFileErrorMessages.multipleOpenAPIDocuments(targetName: targetName, files: docs))
        }
        switch kawarimiConfigs.count {
        case 0, 1:
            break
        default:
            lines.append(
                KawarimiGeneratorConfigSourceMessages.multipleKawarimiGeneratorConfigs(
                    targetName: targetName,
                    files: kawarimiConfigs
                )
            )
        }
        if !lines.isEmpty {
            throw KawarimiPluginError.fileErrors(lines)
        }
        let kawarimiConfig: URL? = kawarimiConfigs.count == 1 ? kawarimiConfigs[0] : nil
        return (docs[0], configs[0], kawarimiConfig)
    }
}

enum KawarimiPluginError: Error, CustomStringConvertible {
    case incompatibleTarget(name: String)
    case fileErrors([String])

    var description: String {
        switch self {
        case .incompatibleTarget(let name):
            return
                "Incompatible target called '\(name)'. Only Swift source targets can be used with the Kawarimi plugin."
        case .fileErrors(let lines):
            return "Issues with required files:\n\(lines.map { "- \($0)" }.joined(separator: "\n"))."
        }
    }
}
