import Foundation
import KawarimiCore
import Testing

@Test(.timeLimit(.minutes(1))) func mockOverrideStringMethodInitRejectsEmptyToken() {
    #expect(MockOverride(path: "/", method: "", statusCode: 200) == nil)
    #expect(MockOverride(path: "/", method: "   ", statusCode: 200) == nil)
}

@Test(.timeLimit(.minutes(1))) func mockOverrideEncodeDecodeWithDelayMs() throws {
    let override = MockOverride(
        path: "/api/greet",
        method: "GET",
        statusCode: 200,
        delayMs: 1500
    )!
    let data = try JSONEncoder().encode(override)
    let decoded = try JSONDecoder().decode(MockOverride.self, from: data)
    #expect(decoded.delayMs == 1500)
}

@Test(.timeLimit(.minutes(1))) func kawarimiConfigStoreNormalizesDelayMs() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-delay-\(UUID().uuidString).json")
    let path = url.path
    let store = try KawarimiConfigStore(configPath: path)
    try await store.configure(MockOverride(path: "/api/greet", method: "GET", statusCode: 200, delayMs: 0)!)
    var overrides = await store.overrides()
    #expect(overrides[0].delayMs == nil)

    try await store.configure(MockOverride(path: "/api/greet", method: "GET", statusCode: 200, delayMs: -5)!)
    overrides = await store.overrides()
    #expect(overrides[0].delayMs == nil)

    try await store.configure(MockOverride(path: "/api/greet", method: "GET", statusCode: 200, delayMs: 99_999)!)
    overrides = await store.overrides()
    #expect(overrides[0].delayMs == 60_000)

    try? FileManager.default.removeItem(at: url)
}

@Test(.timeLimit(.minutes(1))) func mockOverrideEncodeDecodeWithBodyAndContentType() throws {
    let override = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: "GET",
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{\"message\":\"Hello\"}",
        contentType: "application/json"
    )!
    let data = try JSONEncoder().encode(override)
    let decoded = try JSONDecoder().decode(MockOverride.self, from: data)
    #expect(decoded.name == override.name)
    #expect(decoded.path == override.path)
    #expect(decoded.method == override.method)
    #expect(decoded.statusCode == override.statusCode)
    #expect(decoded.isEnabled == override.isEnabled)
    #expect(decoded.body == override.body)
    #expect(decoded.contentType == override.contentType)
    #expect(decoded.exampleId == override.exampleId)
}

@Test(.timeLimit(.minutes(1))) func mockOverrideJSONRoundtripsExampleId() throws {
    let override = MockOverride(
        path: "/api/items",
        method: "GET",
        statusCode: 200,
        exampleId: "success",
        isEnabled: true,
        body: nil,
        contentType: nil
    )!
    let data = try JSONEncoder().encode(override)
    let s = try #require(String(data: data, encoding: .utf8))
    #expect(s.contains("exampleId"))
    let decoded = try JSONDecoder().decode(MockOverride.self, from: data)
    #expect(decoded.exampleId == "success")
}

@Test(.timeLimit(.minutes(1))) func mockOverrideEncodeDecodeWithoutBodyBackwardCompatible() throws {
    let override = MockOverride(
        name: nil,
        path: "/api/greet",
        method: "GET",
        statusCode: 200,
        isEnabled: false,
        body: nil,
        contentType: nil
    )!
    let data = try JSONEncoder().encode(override)
    let decoded = try JSONDecoder().decode(MockOverride.self, from: data)
    #expect(decoded.body == nil)
    #expect(decoded.contentType == nil)
}

@Test(.timeLimit(.minutes(1))) func hengeConfigRoundtripWithBodyOverrides() throws {
    let config = KawarimiConfig(overrides: [
        MockOverride(name: "a", path: "/api/a", method: "GET", statusCode: 200, body: "{}", contentType: "application/json")!,
        MockOverride(name: "b", path: "/api/b", method: "POST", statusCode: 201, body: nil, contentType: nil)!,
    ])
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(KawarimiConfig.self, from: data)
    #expect(decoded.overrides.count == 2)
    #expect(decoded.overrides[0].body == "{}")
    #expect(decoded.overrides[1].body == nil)
}

@Test(.timeLimit(.minutes(1))) func mockOverrideEquatable() {
    let a = MockOverride(path: "/api/x", method: "GET", statusCode: 200, body: "{}")!
    let b = MockOverride(path: "/api/x", method: "GET", statusCode: 200, body: "{}")!
    let c = MockOverride(path: "/api/x", method: "GET", statusCode: 200, body: "{\"x\":1}")!
    #expect(a == b)
    #expect(a != c)
}

@Test(.timeLimit(.minutes(1))) func mockOverrideHasEffectiveCustomBody() {
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: "x", contentType: nil)!.hasEffectiveCustomBody == true)
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: nil, contentType: nil)!.hasEffectiveCustomBody == false)
    #expect(MockOverride(path: "/a", method: "GET", statusCode: 200, body: "", contentType: nil)!.hasEffectiveCustomBody == false)
}

@Test(.timeLimit(.minutes(1))) func mockOverrideNormalizedRowIdAcceptsUUIDOnly() {
    let id = "550E8400-E29B-41D4-A716-446655440000"
    #expect(MockOverrideRowID(rawValue: id)?.rawValue == "550e8400-e29b-41d4-a716-446655440000")
    #expect(MockOverrideRowID(rawValue: "not-uuid") == nil)
    #expect(MockOverrideRowID(rawValue: "   ") == nil)
}

@Test(.timeLimit(.minutes(1))) func mockOverrideDecodeFallsBackToNilForMalformedRowId() throws {
    let json = """
    {
      "rowId": "not-a-uuid",
      "path": "/api/greet",
      "method": "GET",
      "statusCode": 200,
      "isEnabled": true
    }
    """
    let decoded = try JSONDecoder().decode(MockOverride.self, from: Data(json.utf8))
    #expect(decoded.rowId == nil)
    #expect(decoded.path == "/api/greet")
    #expect(decoded.statusCode == 200)
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreNormalizesEmptyBodyToNil() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    let path = url.path
    let store = try KawarimiConfigStore(configPath: path)
    try await store.configure(MockOverride(path: "/api/greet", method: "GET", statusCode: 200, body: "", contentType: "")!)
    let overrides = await store.overrides()
    #expect(overrides.count == 1)
    #expect(overrides[0].body == nil)
    #expect(overrides[0].contentType == nil)
    try? FileManager.default.removeItem(at: url)
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreUsesPathPrefix() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    let path = url.path
    let store = try KawarimiConfigStore(configPath: path, pathPrefix: "/v1")
    try await store.configure(MockOverride(path: "/greet", method: "GET", statusCode: 200)!)
    let overrides = await store.overrides()
    #expect(overrides.count == 1)
    #expect(overrides[0].path == "/v1/greet")
    try? FileManager.default.removeItem(at: url)
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreRemoveOverride() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    let path = url.path
    let store = try KawarimiConfigStore(configPath: path, pathPrefix: "/api")
    try await store.configure(MockOverride(path: "/greet", method: "GET", statusCode: 503, exampleId: "abc", isEnabled: false)!)
    #expect((await store.overrides()).count == 1)
    try await store.removeOverride(MockOverride(path: "/greet", method: "GET", statusCode: 503, exampleId: "abc", isEnabled: false)!)
    #expect((await store.overrides()).isEmpty)
    try await store.removeOverride(MockOverride(path: "/greet", method: "GET", statusCode: 503, exampleId: "abc")!)
    #expect((await store.overrides()).isEmpty)
    try? FileManager.default.removeItem(at: url)
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreConfigureAssignsRowIdWhenMissing() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    let store = try KawarimiConfigStore(configPath: url.path)
    defer { try? FileManager.default.removeItem(at: url) }
    try await store.configure(MockOverride(rowId: nil, path: "/api/greet", method: "GET", statusCode: 200)!)
    let overrides = await store.overrides()
    #expect(overrides.count == 1)
    #expect(overrides[0].rowId != nil)
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreConfigureRowIdMatchWinsOverLegacyFirstHit() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try KawarimiConfigStore(configPath: url.path)
    let targetId = try #require(MockOverrideRowID(rawValue: UUID().uuidString))
    try await store.configure(
        MockOverride(
            rowId: nil,
            path: "/api/greet",
            method: "GET",
            statusCode: 200,
            exampleId: "same",
            body: "{\"v\":1}",
            contentType: "application/json"
        )!
    )
    try await store.configure(
        MockOverride(
            rowId: targetId,
            path: "/api/greet",
            method: "GET",
            statusCode: 200,
            exampleId: "same",
            body: "{\"v\":2}",
            contentType: "application/json"
        )!
    )
    try await store.configure(
        MockOverride(
            rowId: targetId,
            path: "/api/greet",
            method: "GET",
            statusCode: 404,
            exampleId: "same",
            body: "{\"v\":3}",
            contentType: "application/json"
        )!
    )
    let overrides = await store.overrides()
    let target = try #require(overrides.first { $0.rowId == targetId })
    #expect(target.statusCode == 404)
    #expect(target.body == "{\"v\":3}")
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreConfigurePromotesLegacyRowAndKeepsStableRowId() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try KawarimiConfigStore(configPath: url.path)
    try await store.configure(
        MockOverride(
            rowId: nil,
            path: "/api/items",
            method: "GET",
            statusCode: 200,
            exampleId: nil,
            body: "{\"phase\":1}",
            contentType: "application/json"
        )!
    )
    let first = try #require(await store.overrides().first)
    let firstRowId = try #require(first.rowId)
    try await store.configure(
        MockOverride(
            rowId: firstRowId,
            path: "/api/items",
            method: "GET",
            statusCode: 200,
            exampleId: nil,
            body: "{\"phase\":2}",
            contentType: "application/json"
        )!
    )
    _ = await store.reloadFromDisk()
    try await store.configure(
        MockOverride(
            rowId: firstRowId,
            path: "/api/items",
            method: "GET",
            statusCode: 200,
            exampleId: nil,
            body: "{\"phase\":3}",
            contentType: "application/json"
        )!
    )
    let final = try #require(await store.overrides().first)
    #expect(final.rowId == firstRowId)
    #expect(final.body == "{\"phase\":3}")
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreReloadNormalizesUppercaseRowIdAndMatchesByRowId() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let uppercaseRowId = "550E8400-E29B-41D4-A716-446655440000"
    let uppercaseRowIdVO = try #require(MockOverrideRowID(rawValue: uppercaseRowId))
    let config = KawarimiConfig(overrides: [
        MockOverride(
            rowId: uppercaseRowIdVO,
            path: "/api/r",
            method: "GET",
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "{\"v\":1}",
            contentType: "application/json"
        )!,
    ])
    let data = try JSONEncoder().encode(config)
    try data.write(to: url, options: .atomic)
    let store = try KawarimiConfigStore(configPath: url.path)
    let loaded = try #require(await store.overrides().first)
    #expect(loaded.rowId?.rawValue == uppercaseRowId.lowercased())

    try await store.configure(
        MockOverride(
            rowId: uppercaseRowIdVO,
            path: "/api/r",
            method: "GET",
            statusCode: 404,
            exampleId: nil,
            isEnabled: true,
            body: "{\"v\":2}",
            contentType: "application/json"
        )!
    )
    let final = try #require(await store.overrides().first)
    #expect(final.statusCode == 404)
    #expect(final.body == "{\"v\":2}")
    #expect(final.rowId?.rawValue == uppercaseRowId.lowercased())
}

@Test(.timeLimit(.minutes(1))) func hengeConfigStoreRemoveUsesRowIdBeforeLegacy() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("henge-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try KawarimiConfigStore(configPath: url.path)
    let rowIdA = try #require(MockOverrideRowID(rawValue: UUID().uuidString))
    let rowIdB = try #require(MockOverrideRowID(rawValue: UUID().uuidString))
    try await store.configure(
        MockOverride(rowId: rowIdA, path: "/api/r", method: "GET", statusCode: 200, exampleId: "same", body: "{\"id\":\"a\"}", contentType: "application/json")!
    )
    try await store.configure(
        MockOverride(rowId: rowIdB, path: "/api/r", method: "GET", statusCode: 200, exampleId: "same", body: "{\"id\":\"b\"}", contentType: "application/json")!
    )
    try await store.removeOverride(
        MockOverride(rowId: rowIdB, path: "/api/r", method: "GET", statusCode: 200, exampleId: "same")!
    )
    let remaining = await store.overrides()
    #expect(remaining.count == 1)
    #expect(remaining[0].rowId == rowIdA)
}

@Test(.timeLimit(.minutes(1))) func kawarimiConfigStoreThrowsInvalidConfigPath() throws {
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

@Test(.timeLimit(.minutes(1))) func kawarimiConfigStoreThrowsBodyTooLong() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try KawarimiConfigStore(configPath: url.path)
    let hugeBody = String(repeating: "x", count: MockOverride.maxBodyLength + 1)
    var thrown = false
    do {
        try await store.configure(MockOverride(path: "/api/x", method: "GET", statusCode: 200, body: hugeBody)!)
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

@Suite("MockOverride interceptor tie-break sort", .timeLimit(.minutes(1)))
struct MockOverrideInterceptorTieBreakTests {
    private func ov(
        path: String,
        method: String = "GET",
        statusCode: Int = 200,
        exampleId: String? = nil,
        name: String? = nil
    ) -> MockOverride {
        MockOverride(
            name: name,
            path: path,
            method: method,
            statusCode: statusCode,
            exampleId: exampleId,
            isEnabled: true
        )!
    }

    @Test("path ascending breaks ties", .timeLimit(.minutes(1)))
    func pathAscending() {
        let a = ov(path: "/api/zebra")
        let b = ov(path: "/api/apple")
        let c = ov(path: "/api/middle")
        let sorted = MockOverride.sortedForInterceptorTieBreak([a, b, c])
        #expect(sorted.map(\MockOverride.path) == ["/api/apple", "/api/middle", "/api/zebra"])
    }

    @Test("statusCode ascending when path matches", .timeLimit(.minutes(1)))
    func statusCodeAscending() {
        let five = ov(path: "/api/x", statusCode: 500)
        let two = ov(path: "/api/x", statusCode: 200)
        let four = ov(path: "/api/x", statusCode: 404)
        let sorted = MockOverride.sortedForInterceptorTieBreak([five, two, four])
        #expect(sorted.map(\MockOverride.statusCode) == [200, 404, 500])
    }

    @Test("name then exampleId when earlier keys equal", .timeLimit(.minutes(1)))
    func nameAndExampleId() {
        let b = ov(path: "/p", statusCode: 200, exampleId: "e2", name: "b")
        let a = ov(path: "/p", statusCode: 200, exampleId: "e2", name: "a")
        let sorted = MockOverride.sortedForInterceptorTieBreak([b, a])
        #expect(sorted.map(\MockOverride.name) == ["a", "b"])
    }

    @Test("full key order is stable across input permutations", .timeLimit(.minutes(1)))
    func permutationStable() {
        let entries = [
            ov(path: "/b", statusCode: 200, name: "n1"),
            ov(path: "/a", statusCode: 201, name: "n2"),
            ov(path: "/a", statusCode: 200, name: "n1"),
            ov(path: "/a", statusCode: 200, name: "n0"),
        ]
        let expected = MockOverride.sortedForInterceptorTieBreak(entries)
        for _ in 0 ..< 10 {
            let shuffled = entries.shuffled()
            let got = MockOverride.sortedForInterceptorTieBreak(shuffled)
            #expect(got.map(\MockOverride.path) == expected.map(\MockOverride.path))
            #expect(got.map(\MockOverride.statusCode) == expected.map(\MockOverride.statusCode))
            #expect(got.map(\MockOverride.name) == expected.map(\MockOverride.name))
        }
    }
}
