import Foundation
import HTTPTypes

#if canImport(OSLog)
import OSLog
#endif

#if canImport(OSLog)
private let kawarimiScenarioValidationLog = Logger(subsystem: "Kawarimi", category: "KawarimiScenarioValidation")
#endif

private func logScenarioValidationWarning(_ message: String) {
#if canImport(OSLog)
    kawarimiScenarioValidationLog.warning("\(message, privacy: .public)")
#else
    StandardError.write("KawarimiScenarioValidation: \(message)")
#endif
}

public enum KawarimiScenarioValidation {
    public static func warnings(
        scenarios: [KawarimiScenario],
        overrides: [MockOverride]
    ) -> [String] {
        var messages: [String] = []
        var scenarioIdsSeen: Set<String> = []

        for scenario in scenarios {
            let scenarioLabel = scenario.scenarioId
            guard let scenarioId = KawarimiScenarioTokens.normalize(scenario.scenarioId) else {
                messages.append("Invalid scenarioId in \(scenariosPathLabel(scenarioLabel)): \(scenarioLabel)")
                continue
            }
            if !scenarioIdsSeen.insert(scenarioId).inserted {
                messages.append("Duplicate scenarioId '\(scenarioId)'")
            }

            if KawarimiScenarioTokens.normalize(scenario.initial) == nil {
                messages.append("Scenario '\(scenarioId)': invalid initial '\(scenario.initial)'")
            } else if !scenario.cases.contains(where: {
                KawarimiScenarioTokens.normalize($0.kawarimiId) == KawarimiScenarioTokens.normalize(scenario.initial)
            }) {
                messages.append("Scenario '\(scenarioId)': initial '\(scenario.initial)' has no matching case")
            }

            var caseKeys: Set<String> = []
            for scase in scenario.cases {
                guard let kawarimiId = KawarimiScenarioTokens.normalize(scase.kawarimiId) else {
                    messages.append("Scenario '\(scenarioId)': invalid kawarimiId '\(scase.kawarimiId)'")
                    continue
                }
                if let next = scase.next, KawarimiScenarioTokens.normalize(next) == nil {
                    messages.append("Scenario '\(scenarioId)' case '\(kawarimiId)': invalid next '\(next)'")
                }

                let method = scase.endpoint.method.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let path = scase.endpoint.normalizedPath()
                let caseKey = "\(kawarimiId)|\(method)|\(path)"
                if !caseKeys.insert(caseKey).inserted {
                    messages.append(
                        "Scenario '\(scenarioId)': duplicate case for kawarimiId '\(kawarimiId)' at \(method) \(path)"
                    )
                }

                guard overrides.contains(where: { $0.rowId == scase.rowId }) else {
                    messages.append(
                        "Scenario '\(scenarioId)' case '\(kawarimiId)': rowId \(scase.rowId.rawValue) not found in overrides"
                    )
                    continue
                }

                guard let override = overrides.first(where: { $0.rowId == scase.rowId }) else { continue }
                let overridePath = KawarimiRequestPath.pathOnly(override.path)
                if scase.endpoint.normalizedMethod() != override.method || path != overridePath {
                    messages.append(
                        "Scenario '\(scenarioId)' case '\(kawarimiId)': endpoint \(method) \(path) "
                            + "does not match override row \(override.method.rawValue) \(overridePath)"
                    )
                }
            }
        }

        return messages
    }

    public static func logWarningsIfNeeded(
        scenarios: [KawarimiScenario],
        overrides: [MockOverride],
        scenariosPath: String
    ) {
        for message in warnings(scenarios: scenarios, overrides: overrides) {
            logScenarioValidationWarning("\(scenariosPath): \(message)")
        }
    }

    private static func scenariosPathLabel(_ scenarioId: String) -> String {
        "scenario '\(scenarioId)'"
    }
}
