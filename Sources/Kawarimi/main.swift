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
            let stubPolicy = try resolveUnsupportedHandlerStubPolicyFromKawarimiConfig(openAPIPath: inputPath)
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

    private static func resolveUnsupportedHandlerStubPolicyFromKawarimiConfig(
        openAPIPath: String
    ) throws -> KawarimiHandlerUnsupportedStubPolicy {
        let config = try loadKawarimiConfig(openAPIPath: openAPIPath)
        guard let raw = config.unsupportedHandlerStub?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return KawarimiGeneratorConfigYAML.defaults.unsupportedHandlerStubPolicy
        }
        guard let policy = KawarimiHandlerUnsupportedStubPolicy(rawValue: raw) else {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: kawarimiConfigPath(openAPIPath: openAPIPath),
                reason: "未対応の unsupportedHandlerStub: \(raw)（fatalError または throw のみ）"
            )
        }
        return policy
    }

    private static func loadKawarimiConfig(openAPIPath: String) throws -> KawarimiConfig {
        let configPath = kawarimiConfigPath(openAPIPath: openAPIPath)
        guard let data = FileManager.default.contents(atPath: configPath) else {
            return KawarimiConfig()
        }
        do {
            return try JSONDecoder().decode(KawarimiConfig.self, from: data)
        } catch {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configPath,
                reason: "kawarimi.json の JSON を読み込めませんでした: \(error)"
            )
        }
    }

    private static func kawarimiConfigPath(openAPIPath: String) -> String {
        URL(fileURLWithPath: openAPIPath)
            .deletingLastPathComponent()
            .appendingPathComponent("kawarimi.json")
            .path
    }
}
