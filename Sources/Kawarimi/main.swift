import Foundation
import KawarimiCore
import KawarimiJutsu

private enum KawarimiPerfLog {
    static let isEnabled = ProcessInfo.processInfo.environment["KAWARIMI_PERF"] == "1"
    static let prefix = "[kawarimi-perf]"

    static func seconds(_ duration: Duration) -> String {
        let c = duration.components
        let s = Double(c.seconds) + Double(c.attoseconds) * 1e-18
        return String(format: "%.6f", s)
    }

    static func emit(phase: String, duration: Duration, skipped: Bool = false) {
        guard isEnabled else { return }
        let suffix = skipped ? " skipped" : ""
        fputs("\(prefix) phase=\(phase) seconds=\(seconds(duration))\(suffix)\n", stderr)
    }
}

@main
struct Kawarimi {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let prog = CommandLine.arguments.first ?? "Kawarimi"

        for arg in args {
            switch arg {
            case "-h", "--help":
                printHelp(programName: prog)
                exit(0)
            case "--version":
                print(CLIVersion.string)
                exit(0)
            default:
                break
            }
        }

        guard args.count >= 2 else {
            fputs("Usage: \(prog) <openapi path> <output directory>\n", stderr)
            exit(1)
        }
        let inputPath = args[0]
        let outputDirPath = args[1]

        let clock = ContinuousClock()
        let runStarted = clock.now
        var lapStart = runStarted

        do {
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
                    fputs("\(line)\n", stderr)
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
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func printHelp(programName: String) {
        print(
            """
            Usage: \(programName) <openapi path> <output directory>

            Options:
              -h, --help       Show this help
                  --version    Show version
            """
        )
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
