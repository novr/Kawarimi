#if DEBUG
import HTTPTypes
import KawarimiCore
import KawarimiHengeCore

public enum DetailColumnPreviewScenario: String, Sendable {
    case sparseMetadata
    case securityHeavy
    case longJSON
}

package enum DetailColumnPreviewFixtures {
    private struct PreviewFakeResponse: SpecMockResponseProviding {
        var statusCode: Int
        var contentType: String
        var body: String
        var exampleId: String?
        var summary: String?
        var description: String?
    }

    private struct PreviewFakeScopedScheme: SpecScopedSecuritySchemeProviding {
        var name: String
        var scopes: [String]?
    }

    private struct PreviewFakeSecurityRequirement: SpecSecurityRequirementProviding {
        var schemeList: [any SpecScopedSecuritySchemeProviding]
    }

    private struct PreviewFakeSecurityScheme: SpecSecuritySchemeProviding {
        var name: String
        var type: String
        var description: String?
        var apiKeyName: String?
        var apiKeyIn: String?
        var httpScheme: String?
        var bearerFormat: String?
        var openIdConnectURL: String?
    }

    private struct PreviewFakeEndpoint: SpecEndpointProviding {
        var path: String
        var method: HTTPRequest.Method
        var operationId: String
        var tags: [String]?
        var security: [any SpecSecurityRequirementProviding]?
        var responseList: [any SpecMockResponseProviding]
    }

    package static let securityCatalog: [any SpecSecuritySchemeProviding] = [
        PreviewFakeSecurityScheme(
            name: "HeaderA",
            type: "apiKey",
            description: "First application header used for integration tests and documentation previews.",
            apiKeyName: "x-header-a",
            apiKeyIn: "header",
            httpScheme: nil,
            bearerFormat: nil,
            openIdConnectURL: nil
        ),
        PreviewFakeSecurityScheme(
            name: "HeaderB",
            type: "apiKey",
            description: "Second application header; often combined with HeaderA in AND groups.",
            apiKeyName: "x-header-b",
            apiKeyIn: "header",
            httpScheme: nil,
            bearerFormat: nil,
            openIdConnectURL: nil
        ),
        PreviewFakeSecurityScheme(
            name: "BearerAuth",
            type: "http",
            description: "Bearer token for authenticated routes.",
            apiKeyName: nil,
            apiKeyIn: nil,
            httpScheme: "bearer",
            bearerFormat: "JWT",
            openIdConnectURL: nil
        ),
    ]

    private static func endpoint(for scenario: DetailColumnPreviewScenario) -> PreviewFakeEndpoint {
        switch scenario {
        case .sparseMetadata:
            return PreviewFakeEndpoint(
                path: "/greet",
                method: .get,
                operationId: "getGreeting",
                tags: ["Greetings"],
                security: [],
                responseList: [
                    PreviewFakeResponse(
                        statusCode: 200,
                        contentType: "application/json",
                        body: #"{"message":"Hello from API"}"#,
                        exampleId: "success",
                        summary: "Returns a greeting",
                        description: nil
                    ),
                ]
            )
        case .securityHeavy:
            return PreviewFakeEndpoint(
                path: "/items",
                method: .get,
                operationId: "listItems",
                tags: ["Items"],
                security: [
                    PreviewFakeSecurityRequirement(schemeList: [
                        PreviewFakeScopedScheme(name: "HeaderA", scopes: nil),
                        PreviewFakeScopedScheme(name: "HeaderB", scopes: nil),
                        PreviewFakeScopedScheme(name: "BearerAuth", scopes: nil),
                    ]),
                    PreviewFakeSecurityRequirement(schemeList: [
                        PreviewFakeScopedScheme(name: "HeaderA", scopes: nil),
                    ]),
                    PreviewFakeSecurityRequirement(schemeList: [
                        PreviewFakeScopedScheme(name: "BearerAuth", scopes: ["read", "write"]),
                    ]),
                ],
                responseList: [
                    PreviewFakeResponse(
                        statusCode: 200,
                        contentType: "application/json",
                        body: "[]",
                        exampleId: nil,
                        summary: "List all items",
                        description: nil
                    ),
                ]
            )
        case .longJSON:
            return endpoint(for: .sparseMetadata)
        }
    }

    package static func endpointItem(for scenario: DetailColumnPreviewScenario) -> SpecEndpointItem {
        SpecEndpointItem(endpoint(for: scenario))
    }

    package static func securityPresentation(for scenario: DetailColumnPreviewScenario) -> EndpointSecurityPresentation {
        let endpoint = endpoint(for: scenario)
        return SecurityPresentation.endpointPresentation(endpoint: endpoint, catalog: securityCatalog)
    }

    package static func chipOptions(for scenario: DetailColumnPreviewScenario) -> [ResponseChip] {
        let endpoint = endpoint(for: scenario)
        let item = SpecEndpointItem(endpoint)
        let mock = mock(for: scenario)
        return ResponseChips.buildChipOptions(
            mock: mock,
            endpointItem: item,
            endpoint: endpoint,
            overrides: [],
            pathPrefix: ""
        )
    }

    package static func mock(for scenario: DetailColumnPreviewScenario) -> MockOverride {
        let endpoint = endpoint(for: scenario)
        switch scenario {
        case .sparseMetadata:
            return MockOverride(
                name: "getGreeting",
                path: endpoint.path,
                method: endpoint.method,
                statusCode: 200,
                exampleId: "success",
                isEnabled: true,
                body: #"{"message":"Hello from API"}"#,
                contentType: "application/json"
            )
        case .securityHeavy:
            return MockOverride(
                name: "listItems",
                path: endpoint.path,
                method: endpoint.method,
                statusCode: 200,
                exampleId: nil,
                isEnabled: true,
                body: "[]",
                contentType: "application/json"
            )
        case .longJSON:
            return MockOverride(
                name: "getGreeting",
                path: endpoint.path,
                method: endpoint.method,
                statusCode: 200,
                exampleId: "success",
                isEnabled: true,
                body: longJsonBody,
                contentType: "application/json"
            )
        }
    }

    package static var longJsonBody: String {
        let line = "  \"line\": 1,\n"
        return "{\n" + String(repeating: line, count: 500) + "  \"end\": true\n}"
    }
}
#endif
