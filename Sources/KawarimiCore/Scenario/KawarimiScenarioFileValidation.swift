import Foundation

public enum KawarimiScenarioFileValidation {
    public enum Status: Sendable, Equatable {
        case success
        /// Structural or cross-check findings. Prefer this over the removed `.warnings` case.
        /// - Parameters:
        ///   - errors: Fatal-for-CI messages (printed to stderr when using KawarimiValidate).
        ///   - warnings: Soft findings (printed to stdout). Either non-empty → exit code `1`.
        case issues(errors: [String], warnings: [String])
        case fatal(String)

        public var exitCode: Int32 {
            switch self {
            case .success:
                0
            case .issues:
                1
            case .fatal:
                2
            }
        }
    }

    public static func validate(
        configPath: String,
        scenariosPath: String,
        requireScenariosFile: Bool = false,
        specSnapshotPath: String? = nil
    ) -> Status {
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
        } else if requireScenariosFile {
            return .fatal("Scenarios file not found: \(scenariosPath)")
        } else {
            scenarios = []
        }

        let usingSpecSnapshot = specSnapshotPath != nil
        var warnings = KawarimiScenarioValidation.warnings(
            scenarios: scenarios,
            overrides: config.overrides,
            includeRowIdChecks: !usingSpecSnapshot
        )
        var errors: [String] = []

        if let specSnapshotPath {
            let trimmed = specSnapshotPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .fatal("Spec snapshot path is empty")
            }
            guard FileManager.default.fileExists(atPath: trimmed) else {
                return .fatal("Spec snapshot file not found: \(trimmed)")
            }

            let specData: Data
            do {
                specData = try Data(contentsOf: URL(fileURLWithPath: trimmed))
            } catch {
                return .fatal("Failed to read spec snapshot at \(trimmed): \(error.localizedDescription)")
            }

            let spec: HengeSpecSnapshot
            do {
                spec = try JSONDecoder().decode(HengeSpecSnapshot.self, from: specData)
            } catch {
                return .fatal("Invalid spec snapshot at \(trimmed): \(error.localizedDescription)")
            }

            let crossCheck = KawarimiSpecCrossCheck.validate(
                overrides: config.overrides,
                scenarios: scenarios,
                spec: spec
            )
            errors = crossCheck.errors
            warnings.append(contentsOf: crossCheck.warnings)
        }

        if errors.isEmpty && warnings.isEmpty {
            return .success
        }
        return .issues(errors: errors, warnings: warnings)
    }
}
