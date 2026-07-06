import ArgumentParser
import Foundation
import KawarimiCore

@main
struct KawarimiValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kawarimi-validate",
        abstract: "Fail on structural mock/scenario JSON issues that runtime only warns about."
    )

    @Option(help: "Path to kawarimi.json (default: KAWARIMI_CONFIG or ./kawarimi.json).")
    var config: String?

    @Option(help: "Path to kawarimi-scenarios.json (default: KAWARIMI_SCENARIOS_CONFIG or beside config).")
    var scenarios: String?

    func run() throws {
        let configPath = Self.resolvedConfigPath(explicit: config)
        let scenariosPath = Self.resolvedScenariosPath(
            explicit: scenarios,
            configAbsolutePath: configPath
        )
        let requireScenariosFile = KawarimiScenarioDefaults.pathIsExplicit(cliExplicit: scenarios)

        let status = KawarimiScenarioFileValidation.validate(
            configPath: configPath,
            scenariosPath: scenariosPath,
            requireScenariosFile: requireScenariosFile
        )

        switch status {
        case .success:
            break
        case .warnings(let messages):
            for message in messages {
                print(message)
            }
            throw ExitCode(status.exitCode)
        case .fatal(let message):
            StandardError.write(message)
            throw ExitCode(status.exitCode)
        }
    }

    private static func resolveAbsolutePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        if (expanded as NSString).isAbsolutePath {
            return (expanded as NSString).standardizingPath
        }
        let cwd = FileManager.default.currentDirectoryPath
        return (cwd as NSString).appendingPathComponent(expanded)
    }

    static func resolvedConfigPath(explicit: String?) -> String {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return resolveAbsolutePath(trimmed)
            }
        }
        if let env = ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !env.isEmpty
        {
            return resolveAbsolutePath(env)
        }
        return resolveAbsolutePath(KawarimiConfigDefaults.fileName)
    }

    static func resolvedScenariosPath(explicit: String?, configAbsolutePath: String) -> String {
        let resolved = KawarimiScenarioDefaults.resolvedPath(
            explicit: explicit,
            configAbsolutePath: configAbsolutePath
        )
        if (resolved as NSString).isAbsolutePath {
            return (resolved as NSString).standardizingPath
        }
        return resolveAbsolutePath(resolved)
    }
}
