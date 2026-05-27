import Foundation
import KawarimiJutsu
import Testing

private struct CreatedItemPayload: Decodable {
    let id: String
    let name: String
}

@Test func kawarimiTransportUsesCreatedStatusFor201JsonResponse() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let transport = KawarimiJutsu.generateSwiftSource(document: document)

    #expect(transportResponseStatusSwiftName(operationId: "createItem", in: transport) == "created")
    #expect(transportResponseStatusSwiftName(operationId: "getGreeting", in: transport) == "ok")

    let json = try #require(transportMockBodyJSONString(operationId: "createItem", in: transport))
    #expect(json != "{}")
    try assertJSONDecoderAcceptsMockBody(json)
    let object = try KawarimiJutsuTestSupport.parseJSONObject(json) as? [String: Any]
    #expect(object?["id"] != nil)
    #expect(object?["name"] != nil)

    let spec = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let specJSON = try #require(mockResponseBodyJSONString(operationId: "createItem", in: spec))
    try KawarimiJutsuTestSupport.expectNormalizedJSONEqual(json, specJSON)
}

@Test func kawarimiTransportUsesNoContentFor204Response() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let transport = KawarimiJutsu.generateSwiftSource(document: document)

    #expect(transportResponseStatusSwiftName(operationId: "deleteItem", in: transport) == "noContent")
    #expect(transportMockBodyJSONString(operationId: "deleteItem", in: transport) == nil)
    let deleteCase = try #require(transport.range(of: "case \"deleteItem\":"))
    let slice = transport[deleteCase.lowerBound...]
    #expect(slice.contains("HTTPResponse(status: .noContent)"))
    #expect(slice.contains("nil)"))
}

@Test func kawarimiTransport201BodyMatchesOpenAPISchemaShape() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let json = try #require(
        transportMockBodyJSONString(operationId: "createItem", in: KawarimiJutsu.generateSwiftSource(document: document))
    )
    let decoded = try JSONDecoder().decode(CreatedItemPayload.self, from: Data(json.utf8))
    #expect(decoded.id == "")
    #expect(decoded.name == "")
}
@Test func kawarimiJutsuLoadsSpecAndGeneratesMockTransport() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
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
    #expect(source.contains("HTTPResponse(status: .created)"))
    #expect(source.contains("HTTPResponse(status: .noContent)"))
    #expect(source.contains("HTTPBody("))
    #expect(source.contains("message"))
    #expect(source.contains("import OpenAPIRuntime"))
    #expect(source.contains("import HTTPTypes"))
}

