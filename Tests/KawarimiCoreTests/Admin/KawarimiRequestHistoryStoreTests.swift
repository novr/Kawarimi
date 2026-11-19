import Foundation
import HTTPTypes
import KawarimiCore
import Testing

@Suite("KawarimiRequestHistoryStore")
struct KawarimiRequestHistoryStoreTests {
    private func sample(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        method: String = "GET",
        path: String = "/api/widgets",
        operationId: String? = "listWidgets",
        action: RecordedProxyAction = .mock,
        status: Int? = 200
    ) -> RecordedRequest {
        RecordedRequest(
            id: id,
            timestamp: timestamp,
            method: method,
            path: path,
            queryItems: [],
            headers: [:],
            body: nil,
            matchedOperationId: operationId,
            action: action,
            responseStatusCode: status
        )
    }

    @Test func maxEntriesLessThanOneIsClampedToOne() async {
        let store = KawarimiRequestHistoryStore(maxEntries: 0)
        await store.record(sample(id: UUID(), path: "/a"))
        await store.record(sample(id: UUID(), path: "/b"))
        let all = await store.requests()
        #expect(all.count == 1)
        #expect(all[0].path == "/b")
    }

    @Test func ringBufferEvictsOldest() async {
        let store = KawarimiRequestHistoryStore(maxEntries: 2)
        await store.record(sample(path: "/1"))
        await store.record(sample(path: "/2"))
        await store.record(sample(path: "/3"))
        let all = await store.requests()
        #expect(all.map(\.path) == ["/2", "/3"])
    }

    @Test func filtersAreAndCombinedAndMethodIsCaseInsensitive() async {
        let store = KawarimiRequestHistoryStore()
        await store.record(sample(method: "GET", path: "/api/a", operationId: "opA"))
        await store.record(sample(method: "POST", path: "/api/a", operationId: "opA"))
        await store.record(sample(method: "get", path: "/api/b", operationId: "opB"))

        let byMethod = await store.requests(method: "get")
        #expect(byMethod.count == 2)
        #expect(Set(byMethod.map(\.path)) == ["/api/a", "/api/b"])

        let anded = await store.requests(operationId: "opA", path: "/api/a", method: "POST")
        #expect(anded.count == 1)
        #expect(anded[0].method == "POST")
    }

    @Test func clearRemovesAll() async {
        let store = KawarimiRequestHistoryStore()
        await store.record(sample())
        await store.clear()
        let all = await store.requests()
        #expect(all.isEmpty)
    }

    @Test func concurrentRecordRespectsMaxEntries() async {
        let store = KawarimiRequestHistoryStore(maxEntries: 50)
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 200 {
                group.addTask {
                    await store.record(
                        RecordedRequest(
                            id: UUID(),
                            timestamp: Date(),
                            method: "GET",
                            path: "/api/\(i)",
                            queryItems: [],
                            headers: [:],
                            body: nil,
                            matchedOperationId: "op",
                            action: .passthrough,
                            responseStatusCode: 200
                        )
                    )
                }
            }
        }
        let all = await store.requests()
        #expect(all.count == 50)
    }
}

@Test func recordedRequestCodableRoundTripPreservesFractionalSecondOrder() throws {
    let base = Date(timeIntervalSince1970: 1_700_000_000.0)
    let earlier = RecordedRequest(
        id: UUID(),
        timestamp: base.addingTimeInterval(0.001),
        method: "GET",
        path: "/api/a",
        queryItems: [RecordedQueryItem(name: "q", value: "1")],
        headers: ["accept": "application/json"],
        body: "{\"a\":1}",
        matchedOperationId: "opA",
        action: .mock,
        responseStatusCode: 200
    )
    let later = RecordedRequest(
        id: UUID(),
        timestamp: base.addingTimeInterval(0.002),
        method: "POST",
        path: "/api/b",
        queryItems: [RecordedQueryItem(name: "empty", value: nil)],
        headers: ["content-type": "text/plain"],
        body: nil,
        matchedOperationId: nil,
        action: .forward,
        responseStatusCode: nil
    )

    let encoder = KawarimiAdminJSONCoding.makeEncoder()
    let decoder = KawarimiAdminJSONCoding.makeDecoder()
    let data = try encoder.encode([earlier, later])
    let decoded = try decoder.decode([RecordedRequest].self, from: data)
    #expect(decoded.count == 2)
    #expect(decoded[0].id == earlier.id)
    #expect(decoded[1].id == later.id)
    #expect(decoded[0].timestamp < decoded[1].timestamp)
    #expect(decoded[0].queryItems == earlier.queryItems)
    #expect(decoded[1].responseStatusCode == nil)
    #expect(decoded[1].action == .forward)

    let json = try #require(String(data: data, encoding: .utf8))
    #expect(json.contains("."))
}

@Test func recordedRequestEncodesNilOptionalsAsExplicitNull() throws {
    let request = RecordedRequest(
        id: UUID(),
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        method: "GET",
        path: "/api/a",
        queryItems: [RecordedQueryItem(name: "flag", value: nil)],
        headers: [:],
        body: nil,
        matchedOperationId: nil,
        action: .passthrough,
        responseStatusCode: nil
    )
    let data = try KawarimiAdminJSONCoding.makeEncoder().encode(request)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    for key in ["body", "matchedOperationId", "responseStatusCode"] {
        #expect(object[key] is NSNull, "\(key) must be an explicit null")
    }
    let query = try #require((object["queryItems"] as? [[String: Any]])?.first)
    #expect(query["value"] is NSNull)

    let decoded = try KawarimiAdminJSONCoding.makeDecoder().decode(RecordedRequest.self, from: data)
    #expect(decoded.body == nil)
    #expect(decoded.responseStatusCode == nil)
    #expect(decoded.queryItems.first?.value == nil)
}

@Test func kawarimiAdminPathQueryJoinsPathAndQuery() {
    #expect(KawarimiAdminPathQuery.pathWithQuery("/api/__kawarimi/requests", query: nil) == "/api/__kawarimi/requests")
    #expect(KawarimiAdminPathQuery.pathWithQuery("/api/__kawarimi/requests", query: "") == "/api/__kawarimi/requests")
    #expect(
        KawarimiAdminPathQuery.pathWithQuery("/api/__kawarimi/requests", query: "method=GET")
            == "/api/__kawarimi/requests?method=GET"
    )
}

@Test func kawarimiRequestHistoryCaptureNormalizesHeadersAndQuery() {
    var fields = HTTPFields()
    fields.append(HTTPField(name: .authorization, value: "Bearer secret"))
    fields.append(HTTPField(name: HTTPField.Name("Cookie")!, value: "a=1"))
    fields.append(HTTPField(name: .accept, value: "application/json"))
    fields.append(HTTPField(name: .accept, value: "text/plain"))

    let headers = KawarimiRequestHistoryCapture.normalizedHeaders(from: fields)
    #expect(headers["authorization"] == "[redacted]")
    #expect(headers["cookie"] == "[redacted]")
    #expect(headers["accept"] == "text/plain")

    let items = KawarimiRequestHistoryCapture.queryItems(from: "/api/x?a=1&a=2&empty&enc=%2Fpath")
    #expect(items.map(\.name) == ["a", "a", "empty", "enc"])
    #expect(items[0].value == "1")
    #expect(items[1].value == "2")
    #expect(items[2].value == nil)
    #expect(items[3].value == "/path")

    let filters = KawarimiRequestHistoryCapture.requestFilters(
        from: "/api/__kawarimi/requests?operationId=op&path=%2Fapi%2Fx&method=get"
    )
    #expect(filters.operationId == "op")
    #expect(filters.path == "/api/x")
    #expect(filters.method == "get")
}

@Test func kawarimiRequestHistoryCaptureUTF8PrefixTruncatesOnCharacterBoundary() {
    let emoji = "😀"
    let data = Data((String(repeating: emoji, count: 10)).utf8)
    for maxBytes in 4 ... 7 {
        let prefix = KawarimiRequestHistoryCapture.utf8Prefix(from: data, maxBytes: maxBytes)
        #expect(prefix == emoji, "maxBytes=\(maxBytes)")
    }
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: data, maxBytes: 3) == nil)
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: data, maxBytes: 40) == String(repeating: emoji, count: 10))
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: Data(), maxBytes: 10) == nil)
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: Data([0xFF, 0xFE]), maxBytes: 10) == nil)
}

@Test func kawarimiRequestHistoryCaptureUTF8PrefixHandlesDataSlices() {
    let backing = Data("xx".utf8) + Data("héllo".utf8)
    let slice = backing.dropFirst(2)
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: slice, maxBytes: 2) == "h")
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: slice, maxBytes: 3) == "hé")
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: slice, maxBytes: 4) == "hél")
}

@Test func kawarimiRequestHistoryCaptureUTF8PrefixRejectsLargeBinaryQuickly() {
    let binary = Data(repeating: 0xFF, count: KawarimiRequestHistoryCapture.maxBodyUTF8Bytes + 4096)
    let start = ContinuousClock.now
    #expect(KawarimiRequestHistoryCapture.utf8Prefix(from: binary) == nil)
    #expect(ContinuousClock.now - start < .seconds(2))
}

@Test func kawarimiRequestHistoryCaptureQueryItemsToleratesMalformedPercentEncoding() {
    let items = KawarimiRequestHistoryCapture.queryItems(from: "/api/x?a=%zz&b=%&c=%E3%81%82&d=1#frag")
    #expect(items.map(\.name) == ["a", "b", "c", "d"])
    #expect(items[0].value == "%zz")
    #expect(items[1].value == "%")
    #expect(items[2].value == "あ")
    #expect(items[3].value == "1")
    #expect(KawarimiRequestHistoryCapture.queryItems(from: "/api/x?").isEmpty)
    #expect(KawarimiRequestHistoryCapture.queryItems(from: "/api/x").isEmpty)
}
