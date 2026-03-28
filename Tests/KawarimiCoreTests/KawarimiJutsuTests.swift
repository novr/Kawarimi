import Foundation
import KawarimiCore
import Testing

private func fixtureURL(name: String, extension ext: String, subdirectory: String = "Fixtures") -> URL? {
    Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
}

@Test func kawarimiJutsuGenerateKawarimiHandlerSource() throws {
    guard let url = fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml がテストリソースに見つかりません")
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
        Issue.record("IdiomaticConfig/openapi.yaml が見つかりません")
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
    #expect(notFound.description.contains("見つかりません"))
    #expect(notFound.description.contains("/foo"))
}

@Test func kawarimiJutsuLoadsSpecAndGeneratesMockTransport() throws {
    guard let url = fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml がテストリソースに見つかりません")
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
        Issue.record("fixture が見つかりません")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, _) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(source.contains("agreeToTerms"))
    #expect(source.contains("return .ok(.init())"))
}

@Test func kawarimiHandlerUsesFatalErrorStubForStringEnumWhenPolicyIsFatalError() throws {
    guard let url = fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture が見つかりません")
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
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains("createItem"))
    #expect(warnings.joined().contains("Kawarimi warning:"))
}

@Test func kawarimiHandlerUsesFatalErrorStubWhenAccessInternalAndPolicyIsFatalError() throws {
    guard let url = fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture が見つかりません")
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
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains("createItem"))
}

@Test func kawarimiHandlerThrowsForStringEnumWithDefaultFailFastPolicy() throws {
    guard let url = fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture が見つかりません")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    do {
        _ = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
        Issue.record("期待どおりエラーになりませんでした")
    } catch let e as KawarimiJutsuError {
        #expect(e.description.contains("createItem"))
        #expect(e.description.contains("enum"))
    }
}

@Test func kawarimiHandlerThrowsOnMinimalReproOnEnumOperationWithDefaultPolicy() throws {
    guard let url = fixtureURL(name: "openapi-minimal-repro", extension: "yaml") else {
        Issue.record("fixture が見つかりません")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    do {
        _ = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
        Issue.record("enum 応答でエラーになるべき")
    } catch let e as KawarimiJutsuError {
        #expect(e.description.contains("createItem"))
    } catch {
        Issue.record("Unexpected error: \(error)")
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

@Test func kawarimiJutsuGeneratesSpecWithProtocolConformance() throws {
    guard let url = fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml がテストリソースに見つかりません")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    #expect(source.contains("import KawarimiCore"))
    #expect(source.contains("extension KawarimiSpec.Meta: SpecMetaProviding"))
    #expect(source.contains("extension KawarimiSpec.MockResponse: SpecMockResponseProviding"))
    #expect(source.contains("extension KawarimiSpec.Endpoint: SpecEndpointProviding"))
    #expect(source.contains("responseList"))
    #expect(source.contains("public struct SpecResponse: Codable, Sendable"))
    #expect(source.contains("public var meta: KawarimiSpec.Meta"))
    #expect(source.contains("public var endpoints: [KawarimiSpec.Endpoint]"))
    #expect(source.contains("apiPathPrefix"))
    #expect(source.contains("listItems"))
    #expect(source.contains("/items/{id}"))
    #expect(source.contains("responseMap"))
}
