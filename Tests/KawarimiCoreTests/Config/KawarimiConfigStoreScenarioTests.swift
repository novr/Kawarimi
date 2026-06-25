import Foundation
import Testing

@testable import KawarimiCore

@Suite("KawarimiConfigStore scenarios")
struct KawarimiConfigStoreScenarioTests {
    @Test func loadsScenariosFromDedicatedFile() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-scenario-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json").path
        let scenarioPath = dir.appendingPathComponent("kawarimi-scenarios.json").path
        try Data("{\"overrides\":[]}".utf8).write(to: URL(fileURLWithPath: configPath), options: .atomic)
        let rowId = MockOverrideRowID.generate()
        let file = KawarimiScenariosFile(scenarios: [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    .init(
                        kawarimiId: "start",
                        next: "locked",
                        rowId: rowId,
                        endpoint: .init(method: "POST", path: "/api/login")
                    ),
                ]
            ),
        ])
        let encoded = try JSONEncoder().encode(file)
        try encoded.write(to: URL(fileURLWithPath: scenarioPath), options: .atomic)

        let store = try KawarimiConfigStore(configPath: configPath, scenariosPath: scenarioPath)
        let scenarios = await store.scenarios()
        #expect(scenarios.count == 1)
        #expect(scenarios[0].scenarioId == "login")
        #expect(scenarios[0].initial == "start")
    }

    @Test func reloadFromDiskDetectsScenarioChanges() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-scenario-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json").path
        let scenarioPath = dir.appendingPathComponent("kawarimi-scenarios.json").path
        try Data("{\"overrides\":[]}".utf8).write(to: URL(fileURLWithPath: configPath), options: .atomic)
        try Data("{\"scenarios\":[]}".utf8).write(to: URL(fileURLWithPath: scenarioPath), options: .atomic)

        let store = try KawarimiConfigStore(configPath: configPath, scenariosPath: scenarioPath)
        #expect(await store.reloadFromDisk() == .unchanged)

        let updated = KawarimiScenariosFile(scenarios: [
            .init(
                scenarioId: "favorite",
                initial: "start",
                cases: []
            ),
        ])
        try JSONEncoder().encode(updated).write(to: URL(fileURLWithPath: scenarioPath), options: .atomic)

        #expect(await store.reloadFromDisk() == .applied)
        #expect(await store.scenarios().count == 1)
    }
}
