import Foundation
import Testing

@testable import KawarimiCore

@Suite("KawarimiScenarioValidation")
struct KawarimiScenarioValidationTests {
    @Test func warnsOnDuplicateScenarioId() {
        let scenarios = [
            KawarimiScenario(scenarioId: "login", initial: "a", cases: []),
            KawarimiScenario(scenarioId: "login", initial: "b", cases: []),
        ]

        let warnings = KawarimiScenarioValidation.warnings(scenarios: scenarios, overrides: [])
        #expect(warnings.contains(where: { $0.contains("Duplicate scenarioId 'login'") }))
    }

    @Test func warnsOnOrphanRowId() {
        let rowId = MockOverrideRowID.generate()
        let scenarios = [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    .init(
                        kawarimiId: "start",
                        next: nil,
                        rowId: rowId,
                        endpoint: .init(method: "POST", path: "/api/login")
                    ),
                ]
            ),
        ]

        let warnings = KawarimiScenarioValidation.warnings(scenarios: scenarios, overrides: [])
        #expect(warnings.contains(where: { $0.contains("rowId \(rowId.rawValue) not found") }))
    }

    @Test func warnsOnInitialWithoutMatchingCase() {
        let scenarios = [
            KawarimiScenario(scenarioId: "login", initial: "missing", cases: []),
        ]

        let warnings = KawarimiScenarioValidation.warnings(scenarios: scenarios, overrides: [])
        #expect(warnings.contains(where: { $0.contains("initial 'missing' has no matching case") }))
    }

    @Test func resolvesScenariosPathFromEnvironment() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-scenario-env-\(UUID().uuidString)")
        let configPath = dir.appendingPathComponent("kawarimi.json").path
        let scenarioPath = dir.appendingPathComponent("custom-scenarios.json").path

        let resolved = KawarimiScenarioDefaults.resolvedPath(
            explicit: nil,
            configAbsolutePath: configPath,
            environment: [KawarimiScenarioDefaults.environmentKey: scenarioPath]
        )
        #expect(resolved == scenarioPath)
    }

    @Test func explicitScenariosPathOverridesEnvironment() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-scenario-env-\(UUID().uuidString)")
        let configPath = dir.appendingPathComponent("kawarimi.json").path
        let explicitPath = dir.appendingPathComponent("explicit.json").path
        let envPath = dir.appendingPathComponent("from-env.json").path

        let resolved = KawarimiScenarioDefaults.resolvedPath(
            explicit: explicitPath,
            configAbsolutePath: configPath,
            environment: [KawarimiScenarioDefaults.environmentKey: envPath]
        )
        #expect(resolved == explicitPath)
    }

    @Test func pathIsExplicitForCLIAndEnvironment() {
        #expect(
            KawarimiScenarioDefaults.pathIsExplicit(
                cliExplicit: "/tmp/scenarios.json",
                environment: [:]
            )
        )
        #expect(
            KawarimiScenarioDefaults.pathIsExplicit(
                cliExplicit: nil,
                environment: [KawarimiScenarioDefaults.environmentKey: "/tmp/from-env.json"]
            )
        )
        #expect(
            !KawarimiScenarioDefaults.pathIsExplicit(
                cliExplicit: nil,
                environment: [:]
            )
        )
        #expect(
            !KawarimiScenarioDefaults.pathIsExplicit(
                cliExplicit: "  ",
                environment: [:]
            )
        )
    }

    @Test func rejectsInvalidScenariosPathWithParentTraversal() {
        #expect(throws: (any Error).self) {
            _ = try KawarimiConfigStore(
                configPath: "/tmp/kawarimi.json",
                scenariosPath: "../evil.json"
            )
        }
    }
}
