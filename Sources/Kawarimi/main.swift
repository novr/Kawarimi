import Foundation
import KawarimiCore

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
            let stubPolicy = try resolveHandlerStubPolicy(openAPIPath: inputPath)
            let document = try KawarimiJutsu.loadOpenAPISpec(path: inputPath)
            let outputDir = URL(fileURLWithPath: outputDirPath)
            try KawarimiJutsu.generateSwiftSource(document: document).write(to: outputDir.appendingPathComponent("Kawarimi.swift"), atomically: true, encoding: .utf8)
            let (handlerSource, handlerWarnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
                document: document,
                namingStrategy: generatorConfig.namingStrategy,
                accessModifier: generatorConfig.accessModifier,
                handlerStubPolicy: stubPolicy
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

    private static func resolveHandlerStubPolicy(openAPIPath: String) throws -> KawarimiHandlerStubPolicy {
        if let yaml = KawarimiGeneratorConfigFileYAML.handlerStubPolicyBesideOpenAPIYAML(atPath: openAPIPath) {
            return try parseHandlerStubPolicy(raw: yaml.value, configPath: yaml.path)
        }
        return KawarimiGeneratorConfigYAML.defaults.handlerStubPolicy
    }

    private static func parseHandlerStubPolicy(raw: String, configPath: String) throws -> KawarimiHandlerStubPolicy {
        guard let policy = KawarimiHandlerStubPolicy(rawValue: raw) else {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configPath,
                reason: "Unsupported handlerStubPolicy: \(raw) (only fatalError or throw)"
            )
        }
        return policy
    }

}
