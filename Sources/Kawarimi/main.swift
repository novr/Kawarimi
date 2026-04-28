import Foundation
import KawarimiJutsu

private enum KawarimiPerfLog {
    static let prefix = "[kawarimi-perf]"

    static func seconds(_ duration: Duration) -> String {
        let c = duration.components
        let s = Double(c.seconds) + Double(c.attoseconds) * 1e-18
        return String(format: "%.6f", s)
    }

    static func emit(phase: String, duration: Duration) {
        fputs("\(prefix) phase=\(phase) seconds=\(seconds(duration))\n", stderr)
    }
}

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

        let clock = ContinuousClock()
        let runStarted = clock.now
        var lapStart = runStarted

        do {
            let specDir = URL(fileURLWithPath: inputPath).deletingLastPathComponent()
            let generatorConfig = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(
                atPath: inputPath,
                targetNameForErrorMessages: specDir.lastPathComponent
            )
            let stubPolicy = try resolveHandlerStubPolicy(
                openAPIPath: inputPath,
                targetLabel: specDir.lastPathComponent
            )
            let setupElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "setup", duration: setupElapsed)
            lapStart = clock.now

            let document = try KawarimiJutsu.loadOpenAPISpec(path: inputPath)
            let loadElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "load", duration: loadElapsed)
            lapStart = clock.now

            let outputDir = URL(fileURLWithPath: outputDirPath)
            try KawarimiJutsu.generateSwiftSource(document: document).write(to: outputDir.appendingPathComponent("Kawarimi.swift"), atomically: true, encoding: .utf8)
            let kawarimiElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "generate_kawarimi", duration: kawarimiElapsed)
            lapStart = clock.now

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
            let handlerElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "generate_handler", duration: handlerElapsed)
            lapStart = clock.now

            try KawarimiJutsu.generateKawarimiSpecSource(document: document).write(to: outputDir.appendingPathComponent("KawarimiSpec.swift"), atomically: true, encoding: .utf8)
            let specElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "generate_spec", duration: specElapsed)

            let totalElapsed = runStarted.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "total", duration: totalElapsed)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func resolveHandlerStubPolicy(openAPIPath: String, targetLabel: String) throws -> KawarimiHandlerStubPolicy {
        if let yaml = try KawarimiGeneratorConfigFileYAML.handlerStubPolicyBesideOpenAPIYAML(
            atPath: openAPIPath,
            targetNameForErrorMessages: targetLabel
        ) {
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
