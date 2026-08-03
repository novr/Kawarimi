import Foundation
import KawarimiCore
import Testing

@Suite("KawarimiSpecCrossCheck")
struct KawarimiSpecCrossCheckTests {
    @Test func errorsWhenOverrideEndpointMissingFromSpec() throws {
        let spec = try decodeSpec(endpoints: """
        [
          {
            "path": "/api/greet",
            "method": "GET",
            "operationId": "getGreeting",
            "responses": [{ "statusCode": 200, "contentType": "application/json", "body": "{}" }]
          }
        ]
        """)
        let overrides = [
            MockOverride(
                rowId: MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!,
                path: "/api/missing",
                method: .post,
                statusCode: 201
            )
        ]
        let result = KawarimiSpecCrossCheck.validate(overrides: overrides, scenarios: [], spec: spec)
        #expect(result.errors.contains(where: { $0.contains("not found in spec") && $0.contains("/api/missing") }))
        #expect(result.warnings.isEmpty)
    }

    @Test func errorsWhenExampleIdMissingForStatus() throws {
        let spec = try decodeSpec(endpoints: """
        [
          {
            "path": "/api/items",
            "method": "POST",
            "operationId": "createItem",
            "responses": [
              { "statusCode": 201, "contentType": "application/json", "body": "{}", "exampleId": "created" },
              { "statusCode": 400, "contentType": "application/json", "body": "{}", "exampleId": "validation_error" }
            ]
          }
        ]
        """)
        let overrides = [
            MockOverride(
                rowId: MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!,
                path: "/api/items",
                method: .post,
                statusCode: 400,
                exampleId: "not_in_spec"
            )
        ]
        let result = KawarimiSpecCrossCheck.validate(overrides: overrides, scenarios: [], spec: spec)
        #expect(result.errors.contains(where: { $0.contains("exampleId") && $0.contains("not_in_spec") }))
    }

    @Test func errorsWhenScenarioRowIdMissingFromOverrides() throws {
        let spec = try decodeSpec(endpoints: """
        [
          {
            "path": "/api/login",
            "method": "POST",
            "operationId": "login",
            "responses": [{ "statusCode": 200, "contentType": "application/json", "body": "{}" }]
          }
        ]
        """)
        let scenarios = [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    KawarimiScenarioCase(
                        kawarimiId: "start",
                        rowId: MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000099")!,
                        endpoint: KawarimiScenarioEndpoint(method: "POST", path: "/api/login")
                    )
                ]
            )
        ]
        let result = KawarimiSpecCrossCheck.validate(overrides: [], scenarios: scenarios, spec: spec)
        #expect(result.errors.contains(where: { $0.contains("rowId") && $0.contains("not found in overrides") }))
    }

    @Test func warnsWhenScenarioEndpointMissingFromSpec() throws {
        let spec = try decodeSpec(endpoints: """
        [
          {
            "path": "/api/greet",
            "method": "GET",
            "operationId": "getGreeting",
            "responses": [{ "statusCode": 200, "contentType": "application/json", "body": "{}" }]
          }
        ]
        """)
        let rowId = MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!
        let overrides = [
            MockOverride(rowId: rowId, path: "/api/greet", method: .get, statusCode: 200)
        ]
        let scenarios = [
            KawarimiScenario(
                scenarioId: "login",
                initial: "start",
                cases: [
                    KawarimiScenarioCase(
                        kawarimiId: "start",
                        rowId: rowId,
                        endpoint: KawarimiScenarioEndpoint(method: "POST", path: "/api/login")
                    )
                ]
            )
        ]
        let result = KawarimiSpecCrossCheck.validate(overrides: overrides, scenarios: scenarios, spec: spec)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.contains(where: { $0.contains("not found in spec") && $0.contains("/api/login") }))
    }

    @Test func acceptsDefaultExampleIdAgainstUnnamedSpecResponse() throws {
        let spec = try decodeSpec(endpoints: """
        [
          {
            "path": "/api/greet",
            "method": "GET",
            "operationId": "getGreeting",
            "responses": [{ "statusCode": 200, "contentType": "application/json", "body": "{}" }]
          }
        ]
        """)
        let overrides = [
            MockOverride(
                rowId: MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!,
                path: "/api/greet",
                method: .get,
                statusCode: 200,
                exampleId: nil
            )
        ]
        let result = KawarimiSpecCrossCheck.validate(overrides: overrides, scenarios: [], spec: spec)
        #expect(result == KawarimiSpecCrossCheck.Result())
    }

    @Test func skipsExampleIdCheckWhenOverrideHasCustomBody() throws {
        let spec = try decodeSpec(endpoints: """
        [
          {
            "path": "/api/greet",
            "method": "GET",
            "operationId": "getGreeting",
            "responses": [{ "statusCode": 200, "contentType": "application/json", "body": "{}", "exampleId": "success" }]
          }
        ]
        """)
        let overrides = [
            MockOverride(
                rowId: MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!,
                path: "/api/greet",
                method: .get,
                statusCode: 200,
                exampleId: "not_in_spec",
                body: "{\"message\":\"custom\"}"
            )
        ]
        let result = KawarimiSpecCrossCheck.validate(overrides: overrides, scenarios: [], spec: spec)
        #expect(result == KawarimiSpecCrossCheck.Result())
    }

    @Test func skipsStatusAndExampleChecksWhenOverrideHasCustomBody() throws {
        let spec = try decodeSpec(endpoints: """
        [
          {
            "path": "/api/greet",
            "method": "GET",
            "operationId": "getGreeting",
            "responses": [{ "statusCode": 200, "contentType": "application/json", "body": "{}" }]
          }
        ]
        """)
        let overrides = [
            MockOverride(
                rowId: MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!,
                path: "/api/greet",
                method: .get,
                statusCode: 418,
                exampleId: "not_in_spec",
                body: "{\"message\":\"teapot\"}"
            )
        ]
        let result = KawarimiSpecCrossCheck.validate(overrides: overrides, scenarios: [], spec: spec)
        #expect(result == KawarimiSpecCrossCheck.Result())
    }
}

private func decodeSpec(endpoints jsonFragment: String) throws -> HengeSpecSnapshot {
    let json = """
    {
      "meta": {
        "title": "Test",
        "version": "1",
        "serverURL": "https://localhost/api",
        "apiPathPrefix": "/api"
      },
      "endpoints": \(jsonFragment)
    }
    """
    return try JSONDecoder().decode(HengeSpecSnapshot.self, from: Data(json.utf8))
}
