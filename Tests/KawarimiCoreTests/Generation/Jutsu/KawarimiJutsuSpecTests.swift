import Foundation
import KawarimiJutsu
import Testing

@Test func kawarimiJutsuSpecUsesEmptyApiPathPrefixWhenServerHasNoPath() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-root-srv-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let yaml = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    servers:
      - url: http://localhost:3001
    paths:
      /app/setting:
        get:
          operationId: getSetting
          responses:
            '200':
              description: ok
              content:
                application/json:
                  schema:
                    type: object
    """
    let path = tmp.appendingPathComponent("openapi.yaml").path
    try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: path)
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    #expect(source.contains("apiPathPrefix: \"\""))
    #expect(source.contains("path: \"/app/setting\""))
}

@Test func kawarimiJutsuSpecEmitsTags() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    #expect(source.contains("tags: [\"Items\"]"))
    #expect(source.contains("tags: [\"Greetings\"]"))
    #expect(source.contains("public var tags: [String]?"))
    #expect(source.contains("public var parameters: [SpecParameter]?"))

    let greetingBlock = try #require(endpointBlock(operationId: "getGreeting", in: source))
    #expect(greetingBlock.contains("name: \"name\""))
    #expect(greetingBlock.contains("location: .query"))
    #expect(greetingBlock.contains("schemaType: \"string\""))

    let itemBlock = try #require(endpointBlock(operationId: "getItem", in: source))
    #expect(itemBlock.contains("name: \"id\""))
    #expect(itemBlock.contains("location: .path"))
    #expect(itemBlock.contains("required: true"))

    let createBlock = try #require(endpointBlock(operationId: "createItem", in: source))
    #expect(createBlock.contains("parameters: nil"))
}

@Test func kawarimiJutsuSpecEmitsMergedParameters() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-parameters-merge", extension: "yaml") else {
        Issue.record("openapi-parameters-merge.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let block = try #require(endpointBlock(operationId: "mergeParameters", in: source))

    #expect(block.contains("name: \"limit\""))
    #expect(block.contains("description: \"operation limit\""))
    #expect(block.contains("schemaType: \"string\""))
    #expect(block.contains("required: true"))
    #expect(block.contains("name: \"X-Shared\""))
    #expect(block.contains("location: .header"))
    #expect(!block.contains("session"))
    #expect(!block.contains("cookie"))
    #expect(block.contains("name: \"filter\""))
    #expect(block.contains("schemaType: nil"))
}

@Test func kawarimiJutsuSpecEmitsSecuritySchemesAndEffectiveSecurity() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-security", extension: "yaml") else {
        Issue.record("openapi-security.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)

    #expect(source.contains("public struct SecurityScheme: Codable, Sendable"))
    #expect(source.contains("public struct SecurityRequirement: Codable, Sendable"))
    #expect(source.contains("public struct ScopedSecurityScheme: Codable, Sendable"))
    #expect(source.contains("extension KawarimiSpec.SecurityScheme: SpecSecuritySchemeProviding"))
    #expect(source.contains("public static let securitySchemes: [SecurityScheme]?"))
    #expect(source.contains("apiKeyName: \"x-header-a\""))
    #expect(source.contains("httpScheme: \"bearer\""))
    #expect(source.contains("bearerFormat: \"JWT\""))
    #expect(source.contains("public var securitySchemes: [KawarimiSpec.SecurityScheme]?"))

    let inheritBlock = try #require(endpointBlock(operationId: "inheritSecurity", in: source))
    #expect(inheritBlock.contains("name: \"HeaderA\""))
    #expect(inheritBlock.contains("name: \"BearerAuth\""))

    let publicBlock = try #require(endpointBlock(operationId: "publicNoSecurity", in: source))
    #expect(publicBlock.contains("security: nil"))

    let partialBlock = try #require(endpointBlock(operationId: "partialSecurity", in: source))
    #expect(partialBlock.contains("name: \"HeaderA\""))
    #expect(partialBlock.contains("name: \"HeaderB\""))
    #expect(!partialBlock.contains("BearerAuth"))

    let orBlock = try #require(endpointBlock(operationId: "orAlternativeSecurity", in: source))
    let requirementCount = orBlock.components(separatedBy: "SecurityRequirement(").count - 1
    #expect(requirementCount == 2)
}

@Test func kawarimiJutsuGeneratesSpecWithProtocolConformance() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    #expect(source.contains("import HTTPTypes"))
    #expect(source.contains("import KawarimiCore"))
    #expect(source.contains("extension KawarimiSpec.Meta: SpecMetaProviding"))
    #expect(source.contains("extension KawarimiSpec.MockResponse: SpecMockResponseProviding"))
    #expect(source.contains("extension KawarimiSpec.Endpoint: SpecEndpointProviding"))
    #expect(source.contains("responseList"))
    #expect(source.contains("public struct SpecResponse: Codable, Sendable"))
    #expect(source.contains("extension SpecResponse: KawarimiFetchedSpec"))
    #expect(source.contains("securitySchemeCatalog"))
    #expect(source.contains("public var meta: KawarimiSpec.Meta"))
    #expect(source.contains("public var endpoints: [KawarimiSpec.Endpoint]"))
    #expect(source.contains("apiPathPrefix"))
    #expect(source.contains("listItems"))
    #expect(source.contains("/items/{id}"))
    #expect(source.contains("responseMap"))
    #expect(source.contains("[Int: [String: (body: String, contentType: String)]]"))
    #expect(source.contains("\"__default\""))
    let greetBody = try #require(mockResponseBodyJSONString(operationId: "getGreeting", in: source))
    try assertJSONDecoderAcceptsMockBody(greetBody)
    let expected = try KawarimiJutsuTestSupport.normalizedJSONString(#"{"message":"Hello from spec example"}"#)
    #expect(try KawarimiJutsuTestSupport.normalizedJSONString(greetBody) == expected)
}

@Test func kawarimiJutsuSpecEmitsCommonSecuritySchemeTypes() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-security-schemes-catalog", extension: "yaml") else {
        Issue.record("openapi-security-schemes-catalog.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)

    #expect(source.contains("name: \"ApiKeyAuth\""))
    #expect(source.contains("type: \"apiKey\""))
    #expect(source.contains("apiKeyName: \"X-API-Key\""))
    #expect(source.contains("apiKeyIn: \"header\""))

    #expect(source.contains("name: \"BasicAuth\""))
    #expect(source.contains("httpScheme: \"basic\""))

    #expect(source.contains("name: \"BearerAuth\""))
    #expect(source.contains("httpScheme: \"bearer\""))

    #expect(source.contains("name: \"OpenID\""))
    #expect(source.contains("type: \"openIdConnect\""))
    #expect(source.contains("openIdConnectURL: \"https://example.com/.well-known/openid-configuration\""))

    #expect(source.contains("name: \"OAuth2\""))
    #expect(source.contains("type: \"oauth2\""))
    #expect(!source.contains("authorizationUrl"))
    #expect(!source.contains("authorizationCode"))
}

@Test func kawarimiJutsuSpecEmitsNamedExamplesInResponseMap() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-ex-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let yaml = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths:
      /demo:
        get:
          operationId: demoOp
          responses:
            '200':
              description: ok
              content:
                application/json:
                  schema:
                    type: object
                  examples:
                    m_second:
                      value: { "x": 2 }
                    a_first:
                      value: { "x": 1 }
    """
    let path = tmp.appendingPathComponent("openapi.yaml").path
    try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: path)
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    #expect(source.contains("exampleId: \"a_first\""))
    #expect(source.contains("exampleId: \"m_second\""))
    #expect(source.contains("\"a_first\":"))
    #expect(source.contains("\"m_second\":"))
    let rA = try #require(source.range(of: "exampleId: \"a_first\""))
    let rM = try #require(source.range(of: "exampleId: \"m_second\""))
    #expect(rA.lowerBound < rM.lowerBound)
}

@Test func kawarimiJutsuSpecMockUsesSchemaEnumAndOneOfWhenNoExample() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-spec-mock-fallbacks", extension: "yaml") else {
        Issue.record("openapi-spec-mock-fallbacks.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    #expect(source.contains("enum_health_active"))
    #expect(source.contains("oneof_branch_a"))
    let healthBody = try #require(mockResponseBodyJSONString(operationId: "getHealthEnum", in: source))
    let unionBody = try #require(mockResponseBodyJSONString(operationId: "getUnionOneOf", in: source))
    try assertJSONDecoderAcceptsMockBody(healthBody)
    try assertJSONDecoderAcceptsMockBody(unionBody)
}

