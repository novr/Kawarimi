import HTTPTypes
import KawarimiCore
import Testing
@testable import KawarimiHengeCore

private struct FakeSecurityScheme: SpecSecuritySchemeProviding {
    var name: String
    var type: String
    var description: String?
    var apiKeyName: String?
    var apiKeyIn: String?
    var httpScheme: String?
    var bearerFormat: String?
    var openIdConnectURL: String?
}

private struct FakeScopedScheme: SpecScopedSecuritySchemeProviding {
    var name: String
    var scopes: [String]?
}

private struct FakeSecurityRequirement: SpecSecurityRequirementProviding {
    var schemeList: [any SpecScopedSecuritySchemeProviding]
}

private struct FakeSpecEndpoint: SpecEndpointProviding {
    var path: String
    var method: HTTPRequest.Method
    var operationId: String
    var security: [any SpecSecurityRequirementProviding]?
    var responseList: [any SpecMockResponseProviding] = []
}

@Test(.timeLimit(.minutes(1))) func securitySchemeSummaryFormatsApiKeyAndHttp() {
    let apiKey = FakeSecurityScheme(
        name: "ApiKeyAuth",
        type: "apiKey",
        description: nil,
        apiKeyName: "X-API-Key",
        apiKeyIn: "header",
        httpScheme: nil,
        bearerFormat: nil,
        openIdConnectURL: nil
    )
    #expect(SecurityPresentation.schemeSummary(apiKey) == "apiKey (header: X-API-Key)")

    let bearer = FakeSecurityScheme(
        name: "Bearer",
        type: "http",
        description: nil,
        apiKeyName: nil,
        apiKeyIn: nil,
        httpScheme: "bearer",
        bearerFormat: "JWT",
        openIdConnectURL: nil
    )
    #expect(SecurityPresentation.schemeSummary(bearer) == "http (bearer, format: JWT)")
}

@Test(.timeLimit(.minutes(1))) func securityRequirementLinesUseOrSemanticsAsSeparateLines() {
    let endpoint = FakeSpecEndpoint(
        path: "/items",
        method: .get,
        operationId: "list",
        security: [
            FakeSecurityRequirement(schemeList: [FakeScopedScheme(name: "ApiKeyAuth", scopes: nil)]),
            FakeSecurityRequirement(schemeList: [
                FakeScopedScheme(name: "OAuth", scopes: ["read", "write"]),
            ]),
        ]
    )
    let lines = SecurityPresentation.requirementLines(for: endpoint)
    #expect(lines.count == 2)
    #expect(lines[0] == "ApiKeyAuth")
    #expect(lines[1] == "OAuth (scopes: read, write)")
}

@Test(.timeLimit(.minutes(1))) func securityEndpointPresentationResolvesCatalog() {
    let catalog: [any SpecSecuritySchemeProviding] = [
        FakeSecurityScheme(
            name: "ApiKeyAuth",
            type: "apiKey",
            description: "Demo key",
            apiKeyName: "X-API-Key",
            apiKeyIn: "header",
            httpScheme: nil,
            bearerFormat: nil,
            openIdConnectURL: nil
        ),
    ]
    let endpoint = FakeSpecEndpoint(
        path: "/items",
        method: .get,
        operationId: "list",
        security: [FakeSecurityRequirement(schemeList: [FakeScopedScheme(name: "ApiKeyAuth", scopes: nil)])]
    )
    let presentation = SecurityPresentation.endpointPresentation(endpoint: endpoint, catalog: catalog)
    #expect(presentation.requirementLines == ["ApiKeyAuth"])
    #expect(presentation.schemeDetails.count == 1)
    #expect(presentation.schemeDetails[0].summary == "apiKey (header: X-API-Key)")
    #expect(presentation.schemeDetails[0].description == "Demo key")
    #expect(presentation.hasContent)
}

@Test(.timeLimit(.minutes(1))) func securityEndpointPresentationEmptyWhenNoSecurity() {
    let endpoint = FakeSpecEndpoint(path: "/", method: .get, operationId: "root", security: nil)
    let presentation = SecurityPresentation.endpointPresentation(endpoint: endpoint, catalog: nil)
    #expect(presentation.requirementLines.isEmpty)
    #expect(presentation.schemeDetails.isEmpty)
    #expect(!presentation.hasContent)
}
