import Foundation
import KawarimiJutsu
import Testing

private func fixtureURL(name: String, extension ext: String, subdirectory: String = "Fixtures") -> URL? {
    Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
}

// MARK: - Generated KawarimiSpec body JSON (JSONDecoder)

/// Accepts any JSON root value for `JSONDecoder` smoke tests.
private struct AnyJSON: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { return }
        if (try? c.decode(Bool.self)) != nil { return }
        if (try? c.decode(Int.self)) != nil { return }
        if (try? c.decode(Double.self)) != nil { return }
        if (try? c.decode(String.self)) != nil { return }
        if (try? c.decode([String: AnyJSON].self)) != nil { return }
        if (try? c.decode([AnyJSON].self)) != nil { return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }
}

/// Extracts `body: "..."` from the first `MockResponse` after the matching `operationId` in generated source.
private func mockResponseBodyJSONString(operationId: String, in source: String) -> String? {
    let needle = "operationId: \"\(operationId)\""
    guard let opRange = source.range(of: needle) else { return nil }
    let after = source[opRange.upperBound...]
    guard let bodyLabel = after.range(of: "body: \"") else { return nil }
    var i = bodyLabel.upperBound
    var result = ""
    var escaped = false
    while i < after.endIndex {
        let ch = after[i]
        if escaped {
            switch ch {
            case "\"": result.append("\"")
            case "\\": result.append("\\")
            case "n": result.append("\n")
            case "r": result.append("\r")
            case "t": result.append("\t")
            default: result.append(ch)
            }
            escaped = false
        } else if ch == "\\" {
            escaped = true
        } else if ch == "\"" {
            break
        } else {
            result.append(ch)
        }
        i = after.index(after: i)
    }
    return result.isEmpty ? nil : result
}

private func assertJSONDecoderAcceptsMockBody(_ json: String) throws {
    let data = Data(json.utf8)
    _ = try JSONDecoder().decode(AnyJSON.self, from: data)
}

@Test func kawarimiJutsuGenerateKawarimiHandlerSource() throws {
    guard let url = fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)

    #expect(source.contains("public struct KawarimiHandler"))
    #expect(source.contains("APIProtocol"))
    #expect(source.contains("public var onGetGreeting:"))
    #expect(source.contains("try await onGetGreeting(input)"))
    #expect(source.contains("getGreeting"))
    #expect(source.contains("listItems"))
    #expect(source.contains("createItem"))
    #expect(source.contains("getItem"))
    #expect(source.contains("deleteItem"))
    #expect(source.contains("listTags"))
    #expect(source.contains(".ok("))
    #expect(source.contains(".created("))
    #expect(source.contains(".noContent("))
    #expect(source.contains("@Sendable"))
    #expect(source.contains("import OpenAPIRuntime"))
    #expect(source.contains("Operations.getGreeting"))
}

@Test func kawarimiJutsuHandlerUsesIdiomaticOperationsTypeNames() throws {
    guard let openAPIURL = fixtureURL(name: "openapi", extension: "yaml", subdirectory: "Fixtures/IdiomaticConfig") else {
        Issue.record("IdiomaticConfig/openapi.yaml not found")
        return
    }
    let strategy = try KawarimiNamingStrategy.loadBesideOpenAPIYAML(atPath: openAPIURL.path)
    #expect(strategy == .idiomatic)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: openAPIURL.path)
    let (source, _) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: strategy)
    #expect(source.contains("Operations.GetGreeting"))
    #expect(source.contains("func getGreeting"))
    #expect(source.contains("public var onGetGreeting:"))
    #expect(source.contains("try await onGetGreeting(input)"))
}

@Test func kawarimiJutsuErrorDescription() {
    let notFound = KawarimiJutsuError.specFileNotFound(path: "/foo")
    #expect(notFound.description.contains("not found"))
    #expect(notFound.description.contains("/foo"))
}

@Test func kawarimiJutsuLoadsSpecAndGeneratesMockTransport() throws {
    guard let url = fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateSwiftSource(document: document)

    #expect(source.contains("public struct Kawarimi"))
    #expect(source.contains("ClientTransport"))
    #expect(source.contains("case \"getGreeting\""))
    #expect(source.contains("case \"listItems\""))
    #expect(source.contains("case \"deleteItem\""))
    #expect(source.contains("HTTPResponse(status: .ok)"))
    #expect(source.contains("HTTPBody("))
    #expect(source.contains("message"))
    #expect(source.contains("import OpenAPIRuntime"))
    #expect(source.contains("import HTTPTypes"))
}

@Test func kawarimiJutsuThrowsWhenSpecNotFound() throws {
    #expect(throws: KawarimiJutsuError.self) {
        _ = try KawarimiJutsu.loadOpenAPISpec(path: "/nonexistent/openapi.yaml")
    }
}

@Test func kawarimiHandlerSupports200WithNoContentBlock() throws {
    guard let url = fixtureURL(name: "openapi-200-no-json", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, _) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(source.contains("agreeToTerms"))
    #expect(source.contains("return .ok(.init())"))
}

@Test func kawarimiHandlerUsesFatalErrorStubForStringEnumWhenPolicyIsFatalError() throws {
    guard let url = fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        handlerStubPolicy: .fatalError
    )
    #expect(source.contains("fatalError("))
    #expect(source.contains("onCreateItem"))
    #expect(source.contains("// Kawarimi: handlerStubPolicy fatalError"))
    #expect(source.contains("//   [POST /items] createItem"))
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains("createItem"))
    #expect(warnings.joined().contains("Kawarimi warning:"))
    #expect(warnings.joined().contains("Summary: 1 operation"))
}

@Test func kawarimiHandlerUsesFatalErrorStubWhenAccessInternalAndPolicyIsFatalError() throws {
    guard let url = fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        accessModifier: .internal,
        handlerStubPolicy: .fatalError
    )
    #expect(source.contains("internal var onCreateItem:"))
    #expect(source.contains("fatalError("))
    #expect(source.contains("// Kawarimi: handlerStubPolicy fatalError"))
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains("createItem"))
    #expect(warnings.joined().contains("Summary: 1 operation"))
}

@Test func kawarimiHandlerThrowsForStringEnumWithDefaultFailFastPolicy() throws {
    guard let url = fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    do {
        _ = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
        Issue.record("expected error but generation succeeded")
    } catch let e as KawarimiJutsuError {
        #expect(e.description.contains("createItem"))
        #expect(e.description.contains("enum"))
    }
}

@Test func kawarimiNamingStrategyRejectsUnknownValue() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiNaming-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let yaml = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try yaml.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "namingStrategy: fancy\n".write(toFile: config, atomically: true, encoding: .utf8)
    #expect(throws: KawarimiJutsuError.self) {
        _ = try KawarimiNamingStrategy.loadBesideOpenAPIYAML(atPath: openAPIPath)
    }
}

@Test func kawarimiHandlerStubPolicyInOpenAPIGeneratorConfigIsIgnoredAndDefaultsToThrow() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiStubPolicy-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let spec = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try spec.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "handlerStubPolicy: fatalError\n".write(toFile: config, atomically: true, encoding: .utf8)
    let loaded = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
    #expect(loaded.handlerStubPolicy == .throw)
}

@Test func kawarimiHandlerStubPolicyDefaultsToThrowWhenGeneratorKeyOmitted() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiStubOmit-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let spec = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try spec.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "namingStrategy: defensive\n".write(toFile: config, atomically: true, encoding: .utf8)
    let loaded = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
    #expect(loaded.handlerStubPolicy == .throw)
}

@Test func kawarimiAccessModifierRejectsUnknownValue() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiAccess-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let spec = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try spec.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "accessModifier: fileprivate\n".write(toFile: config, atomically: true, encoding: .utf8)
    #expect(throws: KawarimiJutsuError.self) {
        _ = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
    }
}

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

@Test func kawarimiJutsuGeneratesSpecWithProtocolConformance() throws {
    guard let url = fixtureURL(name: "openapi", extension: "yaml") else {
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
    #expect(source.contains("public var meta: KawarimiSpec.Meta"))
    #expect(source.contains("public var endpoints: [KawarimiSpec.Endpoint]"))
    #expect(source.contains("apiPathPrefix"))
    #expect(source.contains("listItems"))
    #expect(source.contains("/items/{id}"))
    #expect(source.contains("responseMap"))
    #expect(source.contains("[Int: [String: (body: String, contentType: String)]]"))
    #expect(source.contains("\"__default\""))
    // Media type example should win over schema fallback for mock body
    #expect(source.contains("Hello from spec example"))
    let greetBody = try #require(mockResponseBodyJSONString(operationId: "getGreeting", in: source))
    try assertJSONDecoderAcceptsMockBody(greetBody)
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
    guard let url = fixtureURL(name: "openapi-spec-mock-fallbacks", extension: "yaml") else {
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
