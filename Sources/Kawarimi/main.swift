import Foundation
import KawarimiCore

/// ビルドプラグインが呼ぶ実行体と同じ生成処理（差分が出ないようにする）。
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
            let generatorConfig = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: inputPath)
            let stubPolicy = try resolveUnsupportedHandlerStubPolicyFromEnv()
            let document = try KawarimiJutsu.loadOpenAPISpec(path: inputPath)
            let outputDir = URL(fileURLWithPath: outputDirPath)
            try KawarimiJutsu.generateSwiftSource(document: document).write(to: outputDir.appendingPathComponent("Kawarimi.swift"), atomically: true, encoding: .utf8)
            let (handlerSource, handlerWarnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
                document: document,
                namingStrategy: generatorConfig.namingStrategy,
                accessModifier: generatorConfig.accessModifier,
                unsupportedHandlerStubPolicy: stubPolicy
            )
            for line in handlerWarnings {
                fputs("\(line)\n", stderr)
            }
            try handlerSource.write(
                to: outputDir.appendingPathComponent("KawarimiHandler.swift"),
                atomically: true,
                encoding: .utf8
            )
            try KawarimiJutsu.generateKawarimiSpecSource(document: document).write(to: outputDir.appendingPathComponent("KawarimiSpec.swift"), atomically: true, encoding: .utf8)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func resolveUnsupportedHandlerStubPolicyFromEnv() throws -> KawarimiHandlerUnsupportedStubPolicy {
        guard let raw = ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return KawarimiGeneratorConfigYAML.defaults.unsupportedHandlerStubPolicy
        }
        guard let policy = KawarimiHandlerUnsupportedStubPolicy(rawValue: raw) else {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: "KAWARIMI_CONFIG",
                reason: "未対応の unsupportedHandlerStub: \(raw)（fatalError または throw のみ）"
            )
        }
        return policy
    }
}
