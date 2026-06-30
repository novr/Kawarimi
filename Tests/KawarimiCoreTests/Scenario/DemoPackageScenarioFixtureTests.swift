import Foundation
import Testing

@testable import KawarimiCore

@Suite("DemoPackage scenario fixtures")
struct DemoPackageScenarioFixtureTests {
    private static var demoPackageDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Example/DemoPackage", isDirectory: true)
    }

    @Test func committedScenarioFixturesHaveNoValidationWarnings() throws {
        let overridesURL = Self.demoPackageDirectory.appendingPathComponent("kawarimi.json.example")
        let scenariosURL = Self.demoPackageDirectory.appendingPathComponent("kawarimi-scenarios.json")

        let overridesData = try Data(contentsOf: overridesURL)
        let scenariosData = try Data(contentsOf: scenariosURL)

        let config = try JSONDecoder().decode(KawarimiConfig.self, from: overridesData)
        let scenariosFile = try JSONDecoder().decode(KawarimiScenariosFile.self, from: scenariosData)

        let warnings = KawarimiScenarioValidation.warnings(
            scenarios: scenariosFile.scenarios,
            overrides: config.overrides
        )
        #expect(warnings.isEmpty, "DemoPackage fixture warnings: \(warnings.joined(separator: "; "))")
    }
}
