import Foundation
import KawarimiCore
import Testing

@Test func kawarimiJutsuGenerateKawarimiHandlerSource() throws {
    guard let url = Bundle.module.url(forResource: "openapi", withExtension: "yaml") else {
        Issue.record("openapi.yaml がテストリソースに見つかりません")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateKawarimiHandlerSource(document: document)

    #expect(source.contains("public struct KawarimiHandler"))
    #expect(source.contains("APIProtocol"))
    #expect(source.contains("getGreeting"))
    #expect(source.contains(".ok("))
    #expect(source.contains("import OpenAPIRuntime"))
}

@Test func kawarimiJutsuErrorDescription() {
    let notFound = KawarimiJutsuError.specFileNotFound(path: "/foo")
    #expect(notFound.description.contains("見つかりません"))
    #expect(notFound.description.contains("/foo"))
}

@Test func kawarimiJutsuLoadsSpecAndGeneratesMockTransport() throws {
    guard let url = Bundle.module.url(forResource: "openapi", withExtension: "yaml") else {
        Issue.record("openapi.yaml がテストリソースに見つかりません")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateSwiftSource(document: document)

    #expect(source.contains("public struct Kawarimi"))
    #expect(source.contains("ClientTransport"))
    #expect(source.contains("case \"getGreeting\""))
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

@Test func kawarimiJutsuGeneratesSpecWithProtocolConformance() throws {
    guard let url = Bundle.module.url(forResource: "openapi", withExtension: "yaml") else {
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
}
