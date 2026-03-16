import Foundation
import KawarimiCore

/// 引数: openapi パス、出力ディレクトリ。Kawarimi.swift / KawarimiHandler.swift / KawarimiSpec.swift を出力する。
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
