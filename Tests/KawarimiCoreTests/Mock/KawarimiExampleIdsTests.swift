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

@Test func kawarimiMockRequestHeadersFilterOverrides() {
    let a = MockOverride(path: "/x", method: "GET", statusCode: 200, exampleId: "one", isEnabled: true)
    let b = MockOverride(path: "/x", method: "GET", statusCode: 200, exampleId: "two", isEnabled: true)
    let c = MockOverride(path: "/x", method: "GET", statusCode: 200, exampleId: nil, isEnabled: true)
    let all = [a, b, c]
    #expect(KawarimiMockRequestHeaders.filterOverrides(all, exampleIdHeaderRaw: nil) == all)
    #expect(KawarimiMockRequestHeaders.filterOverrides(all, exampleIdHeaderRaw: "   ") == all)
    let one = KawarimiMockRequestHeaders.filterOverrides(all, exampleIdHeaderRaw: "one")
    #expect(one.count == 1)
    #expect(one[0].exampleId == "one")
    let def = KawarimiMockRequestHeaders.filterOverrides(all, exampleIdHeaderRaw: "__default")
    #expect(def.count == 1)
    #expect(def[0].exampleId == nil)
    let unknown = KawarimiMockRequestHeaders.filterOverrides(all, exampleIdHeaderRaw: "nope")
    #expect(unknown == all)
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
