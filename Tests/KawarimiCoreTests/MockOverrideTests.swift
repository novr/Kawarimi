import Foundation
import KawarimiCore
import Testing

@Test func mockOverrideEncodeDecodeWithBodyAndContentType() throws {
    let override = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: "GET",
        statusCode: 200,
        exampleId: nil,
        mockId: nil,
        isEnabled: true,
        body: "{\"message\":\"Hello\"}",
        contentType: "application/json"
    )
    let data = try JSONEncoder().encode(override)
    let decoded = try JSONDecoder().decode(MockOverride.self, from: data)
    #expect(decoded.name == override.name)
    #expect(decoded.path == override.path)
    #expect(decoded.method == override.method)
    #expect(decoded.statusCode == override.statusCode)
    #expect(decoded.isEnabled == override.isEnabled)
    #expect(decoded.body == override.body)
    #expect(decoded.contentType == override.contentType)
}

@Test func mockOverrideEncodeDecodeWithoutBodyBackwardCompatible() throws {
    let override = MockOverride(
        name: nil,
        path: "/api/greet",
        method: "GET",
        statusCode: 200,
        isEnabled: false,
        body: nil,
        contentType: nil
    )
    let data = try JSONEncoder().encode(override)
    let decoded = try JSONDecoder().decode(MockOverride.self, from: data)
    #expect(decoded.body == nil)
    #expect(decoded.contentType == nil)
}

@Test func hengeConfigRoundtripWithBodyOverrides() throws {
    let config = KawarimiConfig(overrides: [
        MockOverride(name: "a", path: "/api/a", method: "GET", statusCode: 200, body: "{}", contentType: "application/json"),
        MockOverride(name: "b", path: "/api/b", method: "POST", statusCode: 201, body: nil, contentType: nil),
    ])
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(KawarimiConfig.self, from: data)
    #expect(decoded.overrides.count == 2)
    #expect(decoded.overrides[0].body == "{}")
    #expect(decoded.overrides[1].body == nil)
}

@Test func mockOverrideHasEffectiveCustomBody() {
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: "x", contentType: nil).hasEffectiveCustomBody == true)
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: nil, contentType: nil).hasEffectiveCustomBody == false)
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: "", contentType: nil).hasEffectiveCustomBody == false)
}

@Test func hengeConfigStoreNormalizesEmptyBodyToNil() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    let path = url.path
    let store = KawarimiConfigStore(configPath: path)
    try await store.configure(MockOverride(path: "/api/greet", method: "GET", statusCode: 200, body: "", contentType: ""))
    let overrides = await store.overrides()
    #expect(overrides.count == 1)
    #expect(overrides[0].body == nil)
    #expect(overrides[0].contentType == nil)
    try? FileManager.default.removeItem(at: url)
}

@Test func hengeConfigStoreUsesPathPrefix() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    let path = url.path
    let store = KawarimiConfigStore(configPath: path, pathPrefix: "/v1")
    try await store.configure(MockOverride(path: "/greet", method: "GET", statusCode: 200))
    let overrides = await store.overrides()
    #expect(overrides.count == 1)
    #expect(overrides[0].path == "/v1/greet")
    try? FileManager.default.removeItem(at: url)
}

