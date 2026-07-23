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
    #expect(source.contains("public var requestBodies: [SpecRequestBody]?"))

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
    #expect(createBlock.contains("requestBodies: ["))
    #expect(createBlock.contains("required: true"))
    #expect(createBlock.contains("contentType: \"application/json\""))
    let createRequestBody = try #require(mockRequestBodyJSONString(operationId: "createItem", in: source))
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "createItem-requestBody", actual: createRequestBody)

    let listBlock = try #require(endpointBlock(operationId: "listItems", in: source))
    #expect(listBlock.contains("requestBodies: nil"))
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
    #expect(source.contains("securitySchemes"))

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
    #expect(source.contains("SpecRequestBody"))
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
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "getGreeting", actual: greetBody)
}

@Test func kawarimiJutsuSpecEmitsCommonSecuritySchemeTypes() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-security-schemes-catalog", extension: "yaml") else {
        Issue.record("openapi-security-schemes-catalog.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    #expect(source.contains("name: \"ApiKeyAuth\""))
    #expect(source.contains("name: \"BasicAuth\""))
    #expect(source.contains("name: \"BearerAuth\""))
    #expect(source.contains("name: \"OpenID\""))
    #expect(source.contains("name: \"OAuth2\""))
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
    let healthBody = try #require(mockResponseBodyJSONString(operationId: "getHealthEnum", in: source))
    let unionBody = try #require(mockResponseBodyJSONString(operationId: "getUnionOneOf", in: source))
    try assertJSONDecoderAcceptsMockBody(healthBody)
    try assertJSONDecoderAcceptsMockBody(unionBody)
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "getHealthEnum", actual: healthBody)
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "getUnionOneOf", actual: unionBody)
}

@Test func kawarimiJutsuSpecEmitsNoContentFor204Response() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let block = try #require(endpointBlock(operationId: "deleteItem", in: source))
    #expect(block.contains("statusCode: 204"))
    #expect(block.contains("contentType: \"\""))
    #expect(block.contains("body: \"\""))
    #expect(source.contains("204: [\"__default\": (body: \"\", contentType: \"\")]"))
}

@Test func kawarimiJutsuSpecEmitsNonJSONMediaType() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-xml-success-response", extension: "yaml") else {
        Issue.record("openapi-xml-success-response.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let block = try #require(endpointBlock(operationId: "getReport", in: source))
    #expect(block.contains("contentType: \"application/xml\""))
    #expect(block.contains("body: \"\""))
}

@Test func kawarimiJutsuSpecEmitsNamedRequestBodyExamples() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-request-body-examples", extension: "yaml") else {
        Issue.record("openapi-request-body-examples.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let block = try #require(endpointBlock(operationId: "postItemExamples", in: source))
    #expect(block.contains("exampleId: \"alpha\""))
    #expect(block.contains("exampleId: \"beta\""))
    let rAlpha = try #require(block.range(of: "exampleId: \"alpha\""))
    let rBeta = try #require(block.range(of: "exampleId: \"beta\""))
    #expect(rAlpha.lowerBound < rBeta.lowerBound)
}

@Test func kawarimiJutsuSpecOmitsUnsupportedRequestBodyMediaTypes() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-rb-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let yaml = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths:
      /upload:
        post:
          operationId: uploadFile
          requestBody:
            required: true
            content:
              multipart/form-data:
                schema:
                  type: object
          responses:
            '204':
              description: ok
    """
    let path = tmp.appendingPathComponent("openapi.yaml").path
    try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: path)
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let block = try #require(endpointBlock(operationId: "uploadFile", in: source))
    #expect(block.contains("requestBodies: nil"))
}

@Test func kawarimiJutsuSpecResolvesComponentRequestBodyRef() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-rb-ref-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let yaml = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    components:
      requestBodies:
        ItemBody:
          required: true
          content:
            application/json:
              schema:
                type: object
                properties:
                  name:
                    type: string
    paths:
      /items:
        post:
          operationId: createWithRef
          requestBody:
            $ref: '#/components/requestBodies/ItemBody'
          responses:
            '201':
              description: created
    """
    let path = tmp.appendingPathComponent("openapi.yaml").path
    try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: path)
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let block = try #require(endpointBlock(operationId: "createWithRef", in: source))
    #expect(block.contains("requestBodies: ["))
    #expect(block.contains("required: true"))
    let requestJSON = try #require(mockRequestBodyJSONString(operationId: "createWithRef", in: source))
    try KawarimiJutsuTestSupport.expectNormalizedJSONEqual(requestJSON, "{\"name\":\"\"}")
}
