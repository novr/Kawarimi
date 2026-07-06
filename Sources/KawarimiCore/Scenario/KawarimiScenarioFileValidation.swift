import Foundation

public enum KawarimiScenarioFileValidation {
    public enum Status: Sendable, Equatable {
        case success
        case warnings([String])
        case fatal(String)

        public var exitCode: Int32 {
            switch self {
            case .success:
                0
            case .warnings:
                1
            case .fatal:
                2
            }
        }
    }

    public static func validate(configPath: String, scenariosPath: String) -> Status {
        guard FileManager.default.fileExists(atPath: configPath) else {
            return .fatal("Config file not found: \(configPath)")
        }

        let configData: Data
        do {
            configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        } catch {
            return .fatal("Failed to read config at \(configPath): \(error.localizedDescription)")
        }

        let config: KawarimiConfig
        do {
            config = try JSONDecoder().decode(KawarimiConfig.self, from: configData)
        } catch {
            return .fatal("Invalid kawarimi.json at \(configPath): \(error.localizedDescription)")
        }

        let scenarios: [KawarimiScenario]
        if FileManager.default.fileExists(atPath: scenariosPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: scenariosPath))
                let file = try JSONDecoder().decode(KawarimiScenariosFile.self, from: data)
                scenarios = file.scenarios
            } catch {
                return .fatal("Invalid kawarimi-scenarios.json at \(scenariosPath): \(error.localizedDescription)")
            }
        } else {
            scenarios = []
        }

        let warnings = KawarimiScenarioValidation.warnings(
            scenarios: scenarios,
            overrides: config.overrides
        )
        if warnings.isEmpty {
            return .success
        }
        return .warnings(warnings)
    }
}
