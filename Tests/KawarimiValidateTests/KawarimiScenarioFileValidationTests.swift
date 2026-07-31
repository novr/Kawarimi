import Foundation
import KawarimiCore
import Testing

@Suite("KawarimiScenarioFileValidation")
struct KawarimiScenarioFileValidationTests {
    @Test func succeedsForValidFixturePair() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configPath = repoRoot
            .appendingPathComponent("Example/DemoPackage/kawarimi.json.example")
            .path
        let scenariosPath = repoRoot
            .appendingPathComponent("Example/DemoPackage/kawarimi-scenarios.json")
            .path

        let status = KawarimiScenarioFileValidation.validate(
            configPath: configPath,
            scenariosPath: scenariosPath
        )
        #expect(status == .success)
    }

    @Test func warnsOnOrphanRowId() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let configPath = dir.appendingPathComponent("kawarimi.json")
        let scenariosPath = dir.appendingPathComponent("kawarimi-scenarios.json")

        try """
        {"overrides": []}
        """.write(to: configPath, atomically: true, encoding: .utf8)

        try """
        {
          "scenarios": [
            {
              "scenarioId": "login",
              "initial": "start",
              "cases": [
                {
                  "kawarimiId": "start",
                  "rowId": "00000000-0000-0000-0000-000000000099",
                  "endpoint": { "method": "POST", "path": "/api/login" }
                }
              ]
            }
          ]
        }
        """.write(to: scenariosPath, atomically: true, encoding: .utf8)

        let status = KawarimiScenarioFileValidation.validate(
            configPath: configPath.path,
            scenariosPath: scenariosPath.path
        )
        guard case .issues(let errors, let warnings) = status else {
            Issue.record("Expected issues, got \(status)")
            return
        }
        #expect(errors.isEmpty)
        #expect(warnings.contains(where: { $0.contains("rowId") && $0.contains("not found") }))
    }

    @Test func succeedsWhenConfigIncludesFailureMode() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json")
        try """
        {
          "overrides": [
            {
              "path": "/api/widgets",
              "method": "GET",
              "statusCode": 200,
              "failureMode": "hang"
            }
          ]
        }
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let status = KawarimiScenarioFileValidation.validate(
            configPath: configPath.path,
            scenariosPath: dir.appendingPathComponent("missing-scenarios.json").path
        )
        #expect(status == .success)
    }

    @Test func fatalOnMissingConfig() {
        let status = KawarimiScenarioFileValidation.validate(
            configPath: "/tmp/kawarimi-validate-missing-\(UUID().uuidString).json",
            scenariosPath: "/tmp/kawarimi-validate-missing-scenarios-\(UUID().uuidString).json"
        )
        guard case .fatal(let message) = status else {
            Issue.record("Expected fatal, got \(status)")
            return
        }
        #expect(message.contains("not found"))
    }

    @Test func succeedsWhenDefaultScenariosFileMissing() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let configPath = dir.appendingPathComponent("kawarimi.json")
        try """
        {"overrides": []}
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let status = KawarimiScenarioFileValidation.validate(
            configPath: configPath.path,
            scenariosPath: dir.appendingPathComponent("missing-scenarios.json").path,
            requireScenariosFile: false
        )
        #expect(status == .success)
    }

    @Test func fatalWhenExplicitScenariosFileMissing() throws {
        let path = "/tmp/kawarimi-validate-explicit-missing-\(UUID().uuidString).json"
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let configPath = dir.appendingPathComponent("kawarimi.json")
        try #"{"overrides": []}"#.write(to: configPath, atomically: true, encoding: .utf8)

        let status = KawarimiScenarioFileValidation.validate(
            configPath: configPath.path,
            scenariosPath: path,
            requireScenariosFile: true
        )
        guard case .fatal(let message) = status else {
            Issue.record("Expected fatal, got \(status)")
            return
        }
        #expect(message.contains("Scenarios file not found"))
    }

    @Test func promotesOrphanRowIdToErrorWithSpecSnapshot() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-validate-spec-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configPath = dir.appendingPathComponent("kawarimi.json")
        let scenariosPath = dir.appendingPathComponent("kawarimi-scenarios.json")
        let specPath = dir.appendingPathComponent("spec.json")

        try #"{"overrides": []}"#.write(to: configPath, atomically: true, encoding: .utf8)
        try """
        {
          "scenarios": [
            {
              "scenarioId": "login",
              "initial": "start",
              "cases": [
                {
                  "kawarimiId": "start",
                  "rowId": "00000000-0000-0000-0000-000000000099",
                  "endpoint": { "method": "POST", "path": "/api/login" }
                }
              ]
            }
          ]
        }
        """.write(to: scenariosPath, atomically: true, encoding: .utf8)
        try """
        {
          "meta": {
            "title": "Test",
            "version": "1",
            "serverURL": "https://localhost/api",
            "apiPathPrefix": "/api"
          },
          "endpoints": [
            {
              "path": "/api/login",
              "method": "POST",
              "operationId": "login",
              "responses": [
                {
                  "statusCode": 200,
                  "contentType": "application/json",
                  "body": "{}"
                }
              ]
            }
          ]
        }
        """.write(to: specPath, atomically: true, encoding: .utf8)

        let status = KawarimiScenarioFileValidation.validate(
            configPath: configPath.path,
            scenariosPath: scenariosPath.path,
            specSnapshotPath: specPath.path
        )
        guard case .issues(let errors, let warnings) = status else {
            Issue.record("Expected issues, got \(status)")
            return
        }
        #expect(errors.contains(where: { $0.contains("rowId") && $0.contains("not found in overrides") }))
        #expect(warnings.isEmpty)
    }
}
