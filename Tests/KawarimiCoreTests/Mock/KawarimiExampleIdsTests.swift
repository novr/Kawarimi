import Foundation
import KawarimiCore
import Testing

@Test func kawarimiExampleIdsDefaultKey() {
    #expect(KawarimiExampleIds.defaultResponseMapKey == "__default")
}

@Test func kawarimiExampleIdsLookupNormalizesNilAndEmpty() {
    #expect(KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: nil) == "__default")
    #expect(KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: "") == "__default")
    #expect(KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: "   ") == "__default")
    #expect(KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: "alpha") == "alpha")
}

@Test func kawarimiMockResponseResolverLookup() {
    let map: KawarimiMockResponseResolver.NestedResponseMap = [
        "GET:/api/x": [
            200: [
                "__default": (body: "{\"a\":1}", contentType: "application/json"),
                "alt": (body: "{\"b\":2}", contentType: "application/json"),
            ],
        ],
    ]
    let d = KawarimiMockResponseResolver.lookup(map: map, methodUppercased: "GET", path: "/api/x", statusCode: 200, exampleId: nil)
    #expect(d?.body == "{\"a\":1}")
    let alt = KawarimiMockResponseResolver.lookup(map: map, methodUppercased: "GET", path: "/api/x", statusCode: 200, exampleId: "alt")
    #expect(alt?.body == "{\"b\":2}")
    #expect(KawarimiMockResponseResolver.lookup(map: map, methodUppercased: "GET", path: "/api/x", statusCode: 404, exampleId: nil) == nil)
}

@Test func kawarimiConfigStoreDistinguishesExampleId() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-ex-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try KawarimiConfigStore(configPath: url.path)
    try await store.configure(MockOverride(path: "/api/x", method: "GET", statusCode: 200, exampleId: "a", isEnabled: true))
    try await store.configure(MockOverride(path: "/api/x", method: "GET", statusCode: 200, exampleId: "b", isEnabled: true))
    let list = await store.overrides()
    #expect(list.count == 2)
    try await store.configure(MockOverride(path: "/api/x", method: "GET", statusCode: 200, exampleId: "a", isEnabled: false))
    let after = await store.overrides()
    #expect(after.count == 2)
    let a = try #require(after.first { $0.exampleId == "a" })
    #expect(a.isEnabled == false)
}
