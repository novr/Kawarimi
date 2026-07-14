import ArgumentParser
import Foundation
import KawarimiCore
import KawarimiJutsu

private enum KawarimiPerfLog {
    static let isEnabled = KawarimiEnvironment.isTruthy(ProcessInfo.processInfo.environment["KAWARIMI_PERF"])
    static let prefix = "[kawarimi-perf]"

    static func seconds(_ duration: Duration) -> String {
        let c = duration.components
        let s = Double(c.seconds) + Double(c.attoseconds) * 1e-18
        return String(format: "%.6f", s)
    }

    static func emit(phase: String, duration: Duration, skipped: Bool = false) {
        guard isEnabled else { return }
        let suffix = skipped ? " skipped" : ""
        StandardError.write("\(prefix) phase=\(phase) seconds=\(seconds(duration))\(suffix)")
    }
}

@main
struct KawarimiCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kawarimi",
        abstract: "Generate Kawarimi mock transport, handler, and spec Swift sources from an OpenAPI document.",
        version: BuildInfo.version
    )

    @Argument(help: "Path to the OpenAPI document (YAML or JSON).")
    var openapiPath: String

    @Argument(help: "Directory where generated Swift files are written.")
    var outputDirectory: String

    func run() throws {
        do {
            try KawarimiGenerator.run(openapiPath: openapiPath, outputDirectory: outputDirectory)
        } catch {
            StandardError.write("Error: \(error)")
            throw ExitCode.failure
        }
    }
}

private enum KawarimiGenerator {
    static func run(openapiPath inputPath: String, outputDirectory outputDirPath: String) throws {
        let clock = ContinuousClock()
        let runStarted = clock.now
        var lapStart = runStarted

        let specDir = URL(fileURLWithPath: inputPath).deletingLastPathComponent()
        let targetLabel = specDir.lastPathComponent
        let openAPIConfig = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(
            atPath: inputPath,
            targetNameForErrorMessages: targetLabel
        )
        let kawarimiFile = try KawarimiGeneratorConfigFileYAML.loadBesideOpenAPIYAML(
            atPath: inputPath,
            targetNameForErrorMessages: targetLabel
        )
        let generatorConfig = openAPIConfig.applyingKawarimiGeneratorFile(kawarimiFile)
        let stubPolicy = try resolveHandlerStubPolicy(
            openAPIPath: inputPath,
            kawarimiFile: kawarimiFile
        )
        let setupElapsed = lapStart.duration(to: clock.now)
        KawarimiPerfLog.emit(phase: "setup", duration: setupElapsed)
        lapStart = clock.now

        let document = try KawarimiJutsu.loadOpenAPISpec(path: inputPath)
        let loadElapsed = lapStart.duration(to: clock.now)
        KawarimiPerfLog.emit(phase: "load", duration: loadElapsed)
        lapStart = clock.now

        let outputDir = URL(fileURLWithPath: outputDirPath)

        if generatorConfig.generateKawarimi {
            let kawarimiWritten = try GeneratedFileWriter.writeIfChanged(
                KawarimiJutsu.generateSwiftSource(document: document),
                to: outputDir.appendingPathComponent("Kawarimi.swift")
            )
            let kawarimiElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "generate_kawarimi", duration: kawarimiElapsed, skipped: !kawarimiWritten)
            lapStart = clock.now
        } else {
            KawarimiPerfLog.emit(phase: "generate_kawarimi", duration: .zero, skipped: true)
        }

        if generatorConfig.generateHandler {
            let (handlerSource, handlerWarnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
                document: document,
                namingStrategy: generatorConfig.namingStrategy,
                accessModifier: generatorConfig.accessModifier,
                handlerStubPolicy: stubPolicy
            )
            for line in handlerWarnings {
                StandardError.write(line)
            }
            let handlerWritten = try GeneratedFileWriter.writeIfChanged(
                handlerSource,
                to: outputDir.appendingPathComponent("KawarimiHandler.swift")
            )
            let handlerElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "generate_handler", duration: handlerElapsed, skipped: !handlerWritten)
            lapStart = clock.now
        } else {
            KawarimiPerfLog.emit(phase: "generate_handler", duration: .zero, skipped: true)
        }

        if generatorConfig.generateSpec {
            let specWritten = try GeneratedFileWriter.writeIfChanged(
                KawarimiJutsu.generateKawarimiSpecSource(document: document),
                to: outputDir.appendingPathComponent("KawarimiSpec.swift")
            )
            let specElapsed = lapStart.duration(to: clock.now)
            KawarimiPerfLog.emit(phase: "generate_spec", duration: specElapsed, skipped: !specWritten)
        } else {
            KawarimiPerfLog.emit(phase: "generate_spec", duration: .zero, skipped: true)
        }

        let totalElapsed = runStarted.duration(to: clock.now)
        KawarimiPerfLog.emit(phase: "total", duration: totalElapsed)
    }

    private static func resolveHandlerStubPolicy(
        openAPIPath: String,
        kawarimiFile: KawarimiGeneratorConfigFile?
    ) throws -> KawarimiHandlerStubPolicy {
        if let raw = kawarimiFile?.handlerStubPolicyRaw {
            let configPath = URL(fileURLWithPath: openAPIPath)
                .deletingLastPathComponent()
                .appendingPathComponent("kawarimi-generator-config.yaml")
                .path
            return try parseHandlerStubPolicy(raw: raw, configPath: configPath)
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
