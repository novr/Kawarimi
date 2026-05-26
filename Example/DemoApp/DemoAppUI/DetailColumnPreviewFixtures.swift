#if DEBUG
import HTTPTypes
import KawarimiCore

struct DetailColumnChromeFixture {
    let endpoint: any SpecEndpointProviding
    let initialMock: MockOverride
    let securityCatalog: [any SpecSecuritySchemeProviding]?
}

enum DetailColumnPreviewFixtures {
    private enum Kind {
        case sparseMetadata
        case securityHeavy
        case longJSON
    }

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
        var parameters: [SpecParameter]?
        var responseList: [any SpecMockResponseProviding]
    }

    private static let securityCatalog: [any SpecSecuritySchemeProviding] = [
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

    static var sparseChrome: DetailColumnChromeFixture {
        chromeFixture(for: .sparseMetadata)
    }

    static var securityHeavyChrome: DetailColumnChromeFixture {
        chromeFixture(for: .securityHeavy)
    }

    static var longJSONChrome: DetailColumnChromeFixture {
        chromeFixture(for: .longJSON)
    }

    static var sparseHeader: DetailColumnChromeFixture {
        sparseChrome
    }

    private static func chromeFixture(for kind: Kind) -> DetailColumnChromeFixture {
        let endpoint = endpoint(for: kind)
        return DetailColumnChromeFixture(
            endpoint: endpoint,
            initialMock: mock(for: kind, endpoint: endpoint),
            securityCatalog: kind == .securityHeavy ? securityCatalog : nil
        )
    }

    private static func endpoint(for kind: Kind) -> PreviewFakeEndpoint {
        switch kind {
        case .sparseMetadata:
            return PreviewFakeEndpoint(
                path: "/greet",
                method: .get,
                operationId: "getGreeting",
                tags: ["Greetings"],
                security: [],
                parameters: [
                    SpecParameter(location: .query, name: "name", required: false, description: "name", schemaType: "string"),
                ],
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
                path: "/items/{id}",
                method: .get,
                operationId: "getItem",
                tags: ["Items"],
                parameters: [
                    SpecParameter(location: .path, name: "id", required: true, schemaType: "string"),
                    SpecParameter(location: .query, name: "fields", required: false, description: "Sparse field mask", schemaType: "string"),
                    SpecParameter(location: .header, name: "Accept-Language", required: false, schemaType: "string"),
                ],
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
                        body: #"{"id":"1"}"#,
                        exampleId: nil,
                        summary: "Found",
                        description: nil
                    ),
                ]
            )
        case .longJSON:
            return endpoint(for: .sparseMetadata)
        }
    }

    private static func mock(for kind: Kind, endpoint: PreviewFakeEndpoint) -> MockOverride {
        switch kind {
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
                name: "getItem",
                path: endpoint.path,
                method: endpoint.method,
                statusCode: 200,
                exampleId: nil,
                isEnabled: true,
                body: #"{"id":"1"}"#,
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

    private static var longJsonBody: String {
        let line = "  \"line\": 1,\n"
        return "{\n" + String(repeating: line, count: 500) + "  \"end\": true\n}"
    }
}
#endif
