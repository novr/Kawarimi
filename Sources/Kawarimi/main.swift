import Foundation
import KawarimiCore
import _OpenAPIGeneratorCore

/// 引数: openapi パス、出力ディレクトリ、[config パス（任意）]。Types/Client/Server/Kawarimi.swift を出力する。config 解決は GeneratorConfigResolver に委譲。
@main
struct Kawarimi {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            let prog = args.first ?? "Kawarimi"
            fputs("Usage: \(prog) <openapi path> <output directory> [config path]\n", stderr)
            exit(1)
        }
        let inputPath = args[1]
        let outputDirPath = args[2]
        let configPath = args.count > 3 ? args[3] : nil

        do {
            let openapiURL = URL(fileURLWithPath: inputPath)
            guard let data = FileManager.default.contents(atPath: inputPath) else {
                throw KawarimiJutsuError.specFileNotFound(path: inputPath)
            }
            let inputFile = InMemoryInputFile(absolutePath: openapiURL, contents: data)
            let stderrCollector = StdErrPrintingDiagnosticCollector()
            let diagnostics = ErrorThrowingDiagnosticCollector(upstream: stderrCollector)

            let generatorConfig: OpenAPIGeneratorConfig? = if let configPath {
                ConfigLoader.load(configPath: configPath)
            } else {
                ConfigLoader.load(openapiPath: inputPath)
            }
            let modes = GeneratorConfigResolver.resolveGenerate(generatorConfig: generatorConfig)
            let access = GeneratorConfigResolver.resolveAccessModifier(generatorConfig: generatorConfig)
            let namingStrategy = GeneratorConfigResolver.resolveNamingStrategy(generatorConfig: generatorConfig)
            let additionalImports = generatorConfig?.additionalImports ?? []
            let additionalFileComments = generatorConfig?.additionalFileComments ?? []
            let nameOverrides = generatorConfig?.nameOverrides ?? [:]
            let typeOverrides = _OpenAPIGeneratorCore.TypeOverrides(schemas: generatorConfig?.typeOverrides?.schemas ?? [:])
            let filter = GeneratorConfigResolver.resolveFilter(generatorConfig: generatorConfig)
            let featureFlags = GeneratorConfigResolver.resolveFeatureFlags(generatorConfig: generatorConfig)

            for mode in modes.sorted() {
                let config = Config(
                    mode: mode,
                    access: access,
                    additionalImports: additionalImports,
                    additionalFileComments: additionalFileComments,
                    filter: filter,
                    namingStrategy: namingStrategy,
                    nameOverrides: nameOverrides,
                    typeOverrides: typeOverrides,
                    featureFlags: featureFlags
                )
                let output = try runGenerator(input: inputFile, config: config, diagnostics: diagnostics)
                let outURL = URL(fileURLWithPath: outputDirPath).appendingPathComponent(mode.outputFileName)
                try output.contents.write(to: outURL)
            }

            let document = try KawarimiJutsu.loadOpenAPISpec(path: inputPath)
            let outputDir = URL(fileURLWithPath: outputDirPath)
            try KawarimiJutsu.generateSwiftSource(document: document).write(to: outputDir.appendingPathComponent("Kawarimi.swift"), atomically: true, encoding: .utf8)
            try KawarimiJutsu.generateKawarimiHandlerSource(document: document).write(to: outputDir.appendingPathComponent("KawarimiHandler.swift"), atomically: true, encoding: .utf8)
            try KawarimiJutsu.generateKawarimiSpecSource(document: document).write(to: outputDir.appendingPathComponent("KawarimiSpec.swift"), atomically: true, encoding: .utf8)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}
