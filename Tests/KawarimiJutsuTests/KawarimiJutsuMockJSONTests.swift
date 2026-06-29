import Foundation
@testable import KawarimiJutsu
import Testing

private struct AllOfMergePayload: Codable {
    let a: String
    let b: Int
}

@Test func mockJSONDateTimeWithoutExampleUsesISO8601FallbackNotEmptyString() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-no-example", extension: "yaml") else {
        Issue.record("openapi-datetime-no-example.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let transport = KawarimiJutsu.generateSwiftSource(document: document)
    let transportJSON = try #require(transportMockBodyJSONString(operationId: "getSnapshotNoExample", in: transport))
    #expect(transportJSON.contains("1970-01-01T00:00:00Z"))
    #expect(!transportJSON.contains("\"updatedAt\":\"\""))
    #expect(!transportJSON.contains("\"updatedAt\": \"\""))
    let spec = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let specJSON = try #require(mockResponseBodyJSONString(operationId: "getSnapshotNoExample", in: spec))
    #expect(specJSON == transportJSON)
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "getSnapshotNoExample", actual: transportJSON)
    let decoded = try OpenAPIDateMockSupport.stubJSONDecoder().decode(
        DateTimeNoExamplePayload.self,
        from: Data(transportJSON.utf8)
    )
    #expect(decoded.updatedAt == Date(timeIntervalSince1970: 0))
}

@Test func mockJSONDateOnlyWithoutExampleUses1970FallbackAndMatchesSpec() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-date-only-no-example", extension: "yaml") else {
        Issue.record("openapi-datetime-edge-date-only-no-example.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let transport = KawarimiJutsu.generateSwiftSource(document: document)
    let transportJSON = try #require(transportMockBodyJSONString(operationId: "getDateOnlyNoExample", in: transport))
    #expect(transportJSON.contains("1970-01-01"))
    #expect(!transportJSON.contains("1970-01-01T00:00:00Z"))
    #expect(!transportJSON.contains("\"day\":\"\""))
    let spec = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let specJSON = try #require(mockResponseBodyJSONString(operationId: "getDateOnlyNoExample", in: spec))
    #expect(specJSON == transportJSON)
    let decoded = try OpenAPIDateMockSupport.stubJSONDecoder().decode(
        DateOnlyNoExamplePayload.self,
        from: Data(transportJSON.utf8)
    )
    #expect(decoded.day == Date(timeIntervalSince1970: 0))
}

@Test func mockJSONUnparseableDateTimeExampleUsesISO8601FallbackNotRawString() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-unparseable", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let transport = KawarimiJutsu.generateSwiftSource(document: document)
    let transportJSON = try #require(transportMockBodyJSONString(operationId: "getDateTimeUnparseable", in: transport))
    #expect(transportJSON.contains("1970-01-01T00:00:00Z"))
    #expect(!transportJSON.contains("not-a-valid-instant"))
    let spec = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let specJSON = try #require(mockResponseBodyJSONString(operationId: "getDateTimeUnparseable", in: spec))
    #expect(specJSON == transportJSON)
}

@Test func specMockJSONMatchesHandlerDecodeStubForAllOfDateTime() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-handler-decode", extension: "yaml") else {
        Issue.record("openapi-datetime-handler-decode.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let spec = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let specJSON = try #require(mockResponseBodyJSONString(operationId: "getSnapshotDecode", in: spec))
    let transport = KawarimiJutsu.generateSwiftSource(document: document)
    let transportJSON = try #require(transportMockBodyJSONString(operationId: "getSnapshotDecode", in: transport))
    #expect(specJSON == transportJSON)
    let (handlerSource, _) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    let handlerJSON = try #require(handlerDecodeStubJSONString(witnessName: "onGetSnapshotDecode", in: handlerSource))
    #expect(handlerJSON == specJSON)
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "getSnapshotDecode", actual: specJSON)
}

@Test func mockJSONStopsOnComponentsSchemaRefCycle() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-ref-cycle", extension: "yaml") else {
        Issue.record("openapi-ref-cycle.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let transport = KawarimiJutsu.generateSwiftSource(document: document)
    let transportJSON = try #require(transportMockBodyJSONString(operationId: "getNode", in: transport))
    try assertJSONDecoderAcceptsMockBody(transportJSON)
    let rootObj = try #require(JSONSerialization.jsonObject(with: Data(transportJSON.utf8)) as? [String: Any])
    let level1 = try #require(rootObj["self"] as? [String: Any])
    let level2 = try #require(level1["self"] as? [String: Any])
    #expect(level2.isEmpty)
    #expect(level2["self"] == nil)

    let spec = KawarimiJutsu.generateKawarimiSpecSource(document: document)
    let specJSON = try #require(mockResponseBodyJSONString(operationId: "getNode", in: spec))
    #expect(specJSON == transportJSON)
    try assertJSONDecoderAcceptsMockBody(specJSON)
}

@Test func mockJSONMergesAllOfObjectProperties() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-allof-merge", extension: "yaml") else {
        Issue.record("openapi-allof-merge.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let transport = KawarimiJutsu.generateSwiftSource(document: document)
    let json = try #require(transportMockBodyJSONString(operationId: "getMerged", in: transport))
    try assertJSONDecoderAcceptsMockBody(json)
    let decoded = try JSONDecoder().decode(AllOfMergePayload.self, from: Data(json.utf8))
    #expect(decoded.a == "")
    #expect(decoded.b == 0)
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "getMerged", actual: json)
}
