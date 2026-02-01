import Foundation
import KawarimiCore
import _OpenAPIGeneratorCore

/// 引数: openapi パス、出力ディレクトリ。Types/Client/Server/Kawarimi.swift を出力する。
@main
struct Kawarimi {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            let prog = args.first ?? "Kawarimi"
            fputs("Usage: \(prog) <openapi path> <output directory>\n", stderr)
            exit(1)
        }
        let inputPath = args[1]
        let outputDirPath = args[2]

        do {
            let openapiURL = URL(fileURLWithPath: inputPath)
            guard let data = FileManager.default.contents(atPath: inputPath) else {
                throw KawarimiJutsuError.specFileNotFound(path: inputPath)
            }
            let inputFile = InMemoryInputFile(absolutePath: openapiURL, contents: data)
            let stderrCollector = StdErrPrintingDiagnosticCollector()
            let diagnostics = ErrorThrowingDiagnosticCollector(upstream: stderrCollector)

            for mode in [GeneratorMode.types, .client, .server] {
                let config = Config(
                    mode: mode,
                    access: Config.defaultAccessModifier,
                    namingStrategy: Config.defaultNamingStrategy
                )
                let output = try runGenerator(input: inputFile, config: config, diagnostics: diagnostics)
                let outURL = URL(fileURLWithPath: outputDirPath).appendingPathComponent(mode.outputFileName)
                try output.contents.write(to: outURL)
            }

            let document = try KawarimiJutsu.loadOpenAPISpec(path: inputPath)
            let mockSource = KawarimiJutsu.generateSwiftSource(document: document, typeName: "Kawarimi")
            let kawarimiURL = URL(fileURLWithPath: outputDirPath).appendingPathComponent("Kawarimi.swift")
            try mockSource.write(to: kawarimiURL, atomically: true, encoding: .utf8)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}
