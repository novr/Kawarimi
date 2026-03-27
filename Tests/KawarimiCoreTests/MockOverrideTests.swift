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

@Test func kawarimiConfigDecodesUnsupportedHandlerStubWithoutOverrides() throws {
    let json = """
    {
      "unsupportedHandlerStub": "fatalError"
    }
    """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(KawarimiConfig.self, from: json)
    #expect(decoded.overrides.isEmpty)
    #expect(decoded.unsupportedHandlerStub == "fatalError")
}

@Test func mockOverrideEquatable() {
    let a = MockOverride(path: "/api/x", method: "GET", statusCode: 200, mockId: "m", body: "{}")
    let b = MockOverride(path: "/api/x", method: "GET", statusCode: 200, mockId: "m", body: "{}")
    let c = MockOverride(path: "/api/x", method: "GET", statusCode: 200, mockId: "m", body: "{\"x\":1}")
    #expect(a == b)
    #expect(a != c)
}

@Test func mockOverrideHasEffectiveCustomBody() {
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: "x", contentType: nil).hasEffectiveCustomBody == true)
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: nil, contentType: nil).hasEffectiveCustomBody == false)
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: "", contentType: nil).hasEffectiveCustomBody == false)
}

@Test func hengeConfigStoreNormalizesEmptyBodyToNil() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    let path = url.path
    let store = try KawarimiConfigStore(configPath: path)
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
    let store = try KawarimiConfigStore(configPath: path, pathPrefix: "/v1")
    try await store.configure(MockOverride(path: "/greet", method: "GET", statusCode: 200))
    let overrides = await store.overrides()
    #expect(overrides.count == 1)
    #expect(overrides[0].path == "/v1/greet")
    try? FileManager.default.removeItem(at: url)
}

@Test func kawarimiConfigStoreThrowsInvalidConfigPath() throws {
    var thrown = false
    do {
        _ = try KawarimiConfigStore(configPath: "/foo/../bar.json")
    } catch let e as KawarimiConfigStoreError {
        thrown = true
        if case .invalidConfigPath(let path) = e {
            #expect(path == "/foo/../bar.json")
        }
    }
    #expect(thrown)
}

@Test func kawarimiConfigStoreThrowsBodyTooLong() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try KawarimiConfigStore(configPath: url.path)
    let hugeBody = String(repeating: "x", count: MockOverride.maxBodyLength + 1)
    var thrown = false
    do {
        try await store.configure(MockOverride(path: "/api/x", method: "GET", statusCode: 200, body: hugeBody))
    } catch let e as KawarimiConfigStoreError {
        thrown = true
        if case .bodyTooLong(let actual, let limit) = e {
            #expect(actual == MockOverride.maxBodyLength + 1)
            #expect(limit == MockOverride.maxBodyLength)
        }
    }
    #expect(thrown)
}

// MARK: - sortedForInterceptorTieBreak

@Suite("MockOverride interceptor tie-break sort")
struct MockOverrideInterceptorTieBreakTests {
    private func ov(
        path: String,
        method: String = "GET",
        statusCode: Int = 200,
        exampleId: String? = nil,
        mockId: String? = nil,
        name: String? = nil
    ) -> MockOverride {
        MockOverride(
            name: name,
            path: path,
            method: method,
            statusCode: statusCode,
            exampleId: exampleId,
            mockId: mockId,
            isEnabled: true
        )
    }

    @Test("path ascending breaks ties")
    func pathAscending() {
        let a = ov(path: "/api/zebra")
        let b = ov(path: "/api/apple")
        let c = ov(path: "/api/middle")
        let sorted = MockOverride.sortedForInterceptorTieBreak([a, b, c])
        #expect(sorted.map(\MockOverride.path) == ["/api/apple", "/api/middle", "/api/zebra"])
    }

    @Test("non-nil mockId before nil when path matches")
    func mockIdNonNilBeforeNil() {
        let generic = ov(path: "/api/items/{id}", statusCode: 200, mockId: nil)
        let named = ov(path: "/api/items/{id}", statusCode: 200, mockId: "profile-a")
        let sorted = MockOverride.sortedForInterceptorTieBreak([generic, named])
        #expect(sorted.first?.mockId == "profile-a")
        #expect(sorted.last?.mockId == nil)
    }

    @Test("mockId string ascending when both set")
    func mockIdLexicographic() {
        let z = ov(path: "/x", mockId: "zebra")
        let a = ov(path: "/x", mockId: "alpha")
        let m = ov(path: "/x", mockId: "mid")
        let sorted = MockOverride.sortedForInterceptorTieBreak([z, a, m])
        #expect(sorted.map(\MockOverride.mockId) == ["alpha", "mid", "zebra"])
    }

    @Test("statusCode ascending when path and mockId equal")
    func statusCodeAscending() {
        let five = ov(path: "/api/x", statusCode: 500, mockId: "m")
        let two = ov(path: "/api/x", statusCode: 200, mockId: "m")
        let four = ov(path: "/api/x", statusCode: 404, mockId: "m")
        let sorted = MockOverride.sortedForInterceptorTieBreak([five, two, four])
        #expect(sorted.map(\MockOverride.statusCode) == [200, 404, 500])
    }

    @Test("name then exampleId when earlier keys equal")
    func nameAndExampleId() {
        let b = ov(path: "/p", statusCode: 200, exampleId: "e2", mockId: "m", name: "b")
        let a = ov(path: "/p", statusCode: 200, exampleId: "e2", mockId: "m", name: "a")
        let sorted = MockOverride.sortedForInterceptorTieBreak([b, a])
        #expect(sorted.map(\MockOverride.name) == ["a", "b"])
    }

    @Test("full key order is stable across input permutations")
    func permutationStable() {
        let entries = [
            ov(path: "/b", statusCode: 200, mockId: nil, name: "n1"),
            ov(path: "/a", statusCode: 201, mockId: "z", name: "n2"),
            ov(path: "/a", statusCode: 200, mockId: "z", name: "n1"),
            ov(path: "/a", statusCode: 200, mockId: nil, name: "n0"),
        ]
        let expected = MockOverride.sortedForInterceptorTieBreak(entries)
        for _ in 0 ..< 10 {
            let shuffled = entries.shuffled()
            let got = MockOverride.sortedForInterceptorTieBreak(shuffled)
            #expect(got.map(\MockOverride.path) == expected.map(\MockOverride.path))
            #expect(got.map(\MockOverride.mockId) == expected.map(\MockOverride.mockId))
            #expect(got.map(\MockOverride.statusCode) == expected.map(\MockOverride.statusCode))
            #expect(got.map(\MockOverride.name) == expected.map(\MockOverride.name))
        }
    }
}
