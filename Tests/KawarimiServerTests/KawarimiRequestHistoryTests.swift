import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiServer

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("KawarimiRequestHistory")
struct KawarimiRequestHistoryTests {
    private let disabledUpstreamSettings = KawarimiUpstreamSettings(forwarding: nil)

    private func makeStore(pathPrefix: String = "/api") throws -> (KawarimiConfigStore, URL) {
        let configURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{\"overrides\":[]}".utf8).write(to: configURL)
        let store = try KawarimiConfigStore(configPath: configURL.path, pathPrefix: pathPrefix)
        return (store, configURL)
    }

    @Test func mockRecordsActionStatusHeadersQueryAndBody() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        try await store.configure(
            MockOverride(
                path: "/api/widgets",
                method: .post,
                statusCode: 201,
                body: "{\"ok\":true}",
                contentType: "application/json"
            )
        )
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        var request = HTTPRequest(
            method: .post,
            scheme: "https",
            authority: "example.com",
            path: "/api/widgets?tag=a&tag=b&empty"
        )
        request.headerFields[.authorization] = "Bearer secret"
        request.headerFields[.contentType] = "application/json"
        request.headerFields[HTTPField.Name("Cookie")!] = "sid=1"

        _ = try await middleware.intercept(
            request,
            body: HTTPBody("{\"name\":\"w\"}"),
            metadata: ServerRequestMetadata(),
            operationID: "createWidget",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )

        let recorded = await history.requests()
        #expect(recorded.count == 1)
        let entry = recorded[0]
        #expect(entry.action == .mock)
        #expect(entry.matchedOperationId == "createWidget")
        #expect(entry.responseStatusCode == 201)
        #expect(entry.path == "/api/widgets")
        #expect(entry.method == "POST")
        #expect(entry.body == "{\"name\":\"w\"}")
        #expect(entry.headers["authorization"] == "[redacted]")
        #expect(entry.headers["cookie"] == "[redacted]")
        #expect(entry.headers["content-type"] == "application/json")
        #expect(entry.queryItems.map(\.name) == ["tag", "tag", "empty"])
        #expect(entry.queryItems[0].value == "a")
        #expect(entry.queryItems[2].value == nil)
    }

    @Test func mockFailureModesRecordNilStatus() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        try await store.configure(
            MockOverride(
                path: "/api/widgets",
                method: .get,
                statusCode: 200,
                failureMode: .connectionClose
            )
        )
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/widgets")
        await #expect(throws: KawarimiMockFailureError.connectionClose) {
            _ = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(),
                operationID: "listWidgets",
                next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
            )
        }
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].action == .mock)
        #expect(recorded[0].responseStatusCode == nil)
    }

    @Test func hangRecordsNilStatusBeforeTiming() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        try await store.configure(
            MockOverride(
                path: "/api/widgets",
                method: .get,
                statusCode: 200,
                failureMode: .hang
            )
        )
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/widgets")
        let task = Task {
            _ = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(),
                operationID: "listWidgets",
                next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
            )
        }
        try await Task.sleep(for: .milliseconds(30))
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].responseStatusCode == nil)
        task.cancel()
        _ = try? await task.value
    }

    @Test func passthroughObservesBodyAndRecordsAfterDownstream() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(method: .put, scheme: "https", authority: "example.com", path: "/api/widgets/1")
        let payload = "{\"x\":1}"
        final class Seen: @unchecked Sendable { var body: String? }
        let seen = Seen()
        let (response, _) = try await middleware.intercept(
            request,
            body: HTTPBody(payload),
            metadata: ServerRequestMetadata(),
            operationID: "updateWidget",
            next: { _, body, _ in
                if let body {
                    seen.body = try await String(collecting: body, upTo: 1024)
                }
                return (HTTPResponse(status: .init(code: 204)), nil)
            }
        )
        #expect(response.status.code == 204)
        #expect(seen.body == payload)
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].action == .passthrough)
        #expect(recorded[0].matchedOperationId == "updateWidget")
        #expect(recorded[0].body == payload)
        #expect(recorded[0].responseStatusCode == 204)
    }

    @Test func passthroughDownstreamThrowRecordsNilStatus() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/widgets")
        struct Boom: Error {}
        await #expect(throws: Boom.self) {
            _ = try await middleware.intercept(
                request,
                body: nil,
                metadata: ServerRequestMetadata(),
                operationID: "listWidgets",
                next: { _, _, _ in throw Boom() }
            )
        }
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].action == .passthrough)
        #expect(recorded[0].responseStatusCode == nil)
    }

    @Test func forwardRecordsActionAndStatus() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let history = KawarimiRequestHistoryStore()
        let origin = try #require(URL(string: "https://upstream.test"))
        let forwarding = KawarimiUpstreamForwardingConfiguration(origin: origin)
        let forwarder = KawarimiUpstreamHTTPForwarder(
            upstreamOrigin: origin,
            transport: .mock { request, body in
                if let body {
                    _ = try await Data(collecting: body, upTo: 1024)
                }
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 202,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, nil)
            }
        )
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            forwarding: forwarding,
            forwarder: forwarder,
            historyStore: history
        )
        let request = HTTPRequest(method: .post, scheme: "http", authority: "127.0.0.1", path: "/api/greet")
        let (response, _) = try await middleware.intercept(
            request,
            body: HTTPBody("hi"),
            metadata: ServerRequestMetadata(),
            operationID: "greet",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        #expect(response.status.code == 202)
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].action == .forward)
        #expect(recorded[0].matchedOperationId == "greet")
        #expect(recorded[0].body == "hi")
        #expect(recorded[0].responseStatusCode == 202)
    }

    @Test func bodyPrefixObserverForwardsIdenticalBytes() async throws {
        let original = Data((0 ..< 4096).map { UInt8($0 % 251) })
        let body = HTTPBody(original)
        let (wrapped, _) = KawarimiHTTPBodyPrefixObserver.tee(body)
        let collected = try await Data(collecting: try #require(wrapped), upTo: original.count + 1)
        #expect(collected == original)
    }

    @Test func bodyPrefixObserverPreservesLengthAndIterationBehavior() async throws {
        let known = HTTPBody("abc")
        let (wrappedKnown, _) = KawarimiHTTPBodyPrefixObserver.tee(known)
        #expect(wrappedKnown?.length == known.length)
        #expect(wrappedKnown?.iterationBehavior == known.iterationBehavior)

        let stream = AsyncStream<ArraySlice<UInt8>> { continuation in
            continuation.yield(ArraySlice("abc".utf8))
            continuation.finish()
        }
        let unknown = HTTPBody(stream, length: .unknown, iterationBehavior: .single)
        let (wrappedUnknown, _) = KawarimiHTTPBodyPrefixObserver.tee(unknown)
        #expect(wrappedUnknown?.length == .unknown)
        #expect(wrappedUnknown?.iterationBehavior == .single)
    }

    @Test func bodyPrefixObserverIsLazyAndDoesNotReadAhead() async throws {
        final class PullSource: @unchecked Sendable {
            private let lock = NSLock()
            private var pulled = 0
            private let chunks = (0 ..< 8).map { ArraySlice("chunk\($0)".utf8) }
            var value: Int { lock.lock(); defer { lock.unlock() }; return pulled }
            func pull() -> ArraySlice<UInt8>? {
                lock.lock()
                defer { lock.unlock() }
                defer { pulled += 1 }
                return pulled < chunks.count ? chunks[pulled] : nil
            }
        }
        let pulls = PullSource()
        let source = AsyncStream<ArraySlice<UInt8>> { pulls.pull() }
        let body = HTTPBody(source, length: .unknown, iterationBehavior: .single)
        let (wrapped, observer) = KawarimiHTTPBodyPrefixObserver.tee(body)
        _ = wrapped
        try await Task.sleep(for: .milliseconds(50))
        #expect(pulls.value == 0)
        #expect(observer?.capturedBody() == nil)

        var iterator = try #require(wrapped).makeAsyncIterator()
        _ = try await iterator.next()
        #expect(pulls.value == 1)
        #expect(observer?.capturedBody() == "chunk0")
    }

    @Test func bodyPrefixObserverResetsAcrossMultiplePasses() async throws {
        let body = HTTPBody("hello")
        let (wrapped, observer) = KawarimiHTTPBodyPrefixObserver.tee(body)
        let wrappedBody = try #require(wrapped)
        _ = try await Data(collecting: wrappedBody, upTo: 64)
        _ = try await Data(collecting: wrappedBody, upTo: 64)
        #expect(observer?.capturedBody() == "hello")
    }

    @Test func passthroughRecordsNilBodyWhenHandlerDoesNotRead() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/widgets")
        _ = try await middleware.intercept(
            request,
            body: HTTPBody("never-read"),
            metadata: ServerRequestMetadata(),
            operationID: "createWidget",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].body == nil)
    }

    @Test func malformedQueryDoesNotCrashAndIsRecorded() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/api/widgets?q=%zz&r=%"
        )
        _ = try await middleware.intercept(
            request,
            body: nil,
            metadata: ServerRequestMetadata(),
            operationID: "listWidgets",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].queryItems.map(\.name) == ["q", "r"])
        #expect(recorded[0].queryItems.map(\.value) == ["%zz", "%"])
    }

    @Test func binaryMockBodyRecordsNilWithoutAffectingResponse() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        try await store.configure(
            MockOverride(path: "/api/widgets", method: .post, statusCode: 201, body: "{}", contentType: "application/json")
        )
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/widgets")
        let (response, _) = try await middleware.intercept(
            request,
            body: HTTPBody(Data(repeating: 0xFF, count: KawarimiRequestHistoryCapture.maxBodyUTF8Bytes + 1024)),
            metadata: ServerRequestMetadata(),
            operationID: "createWidget",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        #expect(response.status.code == 201)
        let recorded = await history.requests()
        #expect(recorded.first?.body == nil)
    }

    @Test func mockBodyReadFailureStillReturnsMockAndRecords() async throws {
        struct ReadFailure: Error {}
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        try await store.configure(
            MockOverride(path: "/api/widgets", method: .post, statusCode: 201, body: "{}", contentType: "application/json")
        )
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let failing = AsyncThrowingStream<ArraySlice<UInt8>, Error> { continuation in
            continuation.finish(throwing: ReadFailure())
        }
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/widgets")
        let (response, _) = try await middleware.intercept(
            request,
            body: HTTPBody(failing, length: .unknown, iterationBehavior: .single),
            metadata: ServerRequestMetadata(),
            operationID: "createWidget",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        #expect(response.status.code == 201)
        let recorded = await history.requests()
        #expect(recorded.count == 1)
        #expect(recorded[0].body == nil)
        #expect(recorded[0].responseStatusCode == 201)
    }

    @Test func mockBodyTruncatesAtOneMiBUTF8Boundary() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        try await store.configure(
            MockOverride(path: "/api/widgets", method: .post, statusCode: 200)
        )
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let emoji = "😀"
        let oversized = String(repeating: emoji, count: (KawarimiRequestHistoryCapture.maxBodyUTF8Bytes / emoji.utf8.count) + 8)
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/widgets")
        _ = try await middleware.intercept(
            request,
            body: HTTPBody(oversized),
            metadata: ServerRequestMetadata(),
            operationID: "createWidget",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        let recorded = await history.requests()
        let body = try #require(recorded.first?.body)
        #expect(body.utf8.count <= KawarimiRequestHistoryCapture.maxBodyUTF8Bytes)
        #expect(body.last == "😀".first)
    }

    @Test func adminPathIsNotRecordedEvenIfIntercepted() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let history = KawarimiRequestHistoryStore()
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings,
            historyStore: history
        )
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "example.com",
            path: "/api/__kawarimi/status"
        )
        _ = try await middleware.intercept(
            request,
            body: nil,
            metadata: ServerRequestMetadata(),
            operationID: "admin",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        let recorded = await history.requests()
        #expect(recorded.isEmpty)
    }

    @Test func historyStoreNilLeavesExistingBehavior() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        try await store.configure(
            MockOverride(
                path: "/api/widgets",
                method: .get,
                statusCode: 201,
                body: "{\"mocked\":true}",
                contentType: "application/json"
            )
        )
        let middleware = KawarimiServerMiddleware(
            store: store,
            responseMap: [:],
            upstreamSettings: disabledUpstreamSettings
        )
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/widgets")
        let (response, body) = try await middleware.intercept(
            request,
            body: HTTPBody("ignored-when-nil-store"),
            metadata: ServerRequestMetadata(),
            operationID: "listWidgets",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )
        #expect(response.status.code == 201)
        let collected = try await String(collecting: body!, upTo: 1024)
        #expect(collected == "{\"mocked\":true}")
    }
}

@Suite("KawarimiAdminHTTPHandler request history")
struct KawarimiAdminHTTPHandlerRequestHistoryTests {
    private func makeStore(pathPrefix: String = "/api") throws -> (KawarimiConfigStore, URL) {
        let configURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{\"overrides\":[]}".utf8).write(to: configURL)
        let store = try KawarimiConfigStore(configPath: configURL.path, pathPrefix: pathPrefix)
        return (store, configURL)
    }

    @Test func requestsWithoutStoreReturnsNil() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let getResult = try await handler.handle(
            request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/__kawarimi/requests"),
            body: nil
        )
        #expect(getResult == nil)
        let deleteResult = try await handler.handle(
            request: HTTPRequest(method: .delete, scheme: "https", authority: "example.com", path: "/api/__kawarimi/requests"),
            body: nil
        )
        #expect(deleteResult == nil)
    }

    @Test func getFiltersAndDeleteClear() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }
        let history = KawarimiRequestHistoryStore()
        await history.record(
            RecordedRequest(
                id: UUID(),
                timestamp: Date(),
                method: "GET",
                path: "/api/a",
                queryItems: [],
                headers: [:],
                body: nil,
                matchedOperationId: "opA",
                action: .mock,
                responseStatusCode: 200
            )
        )
        await history.record(
            RecordedRequest(
                id: UUID(),
                timestamp: Date(),
                method: "POST",
                path: "/api/b",
                queryItems: [],
                headers: [:],
                body: nil,
                matchedOperationId: "opB",
                action: .passthrough,
                responseStatusCode: 201
            )
        )
        let handler = KawarimiAdminHTTPHandler(
            store: store,
            historyStore: history,
            specWireData: { Data("{}".utf8) }
        )

        let filteredPath = KawarimiAdminPathQuery.pathWithQuery(
            "/api/__kawarimi/requests",
            query: "operationId=opA&method=GET"
        )
        let (getResponse, getBody) = try #require(
            try await handler.handle(
                request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: filteredPath),
                body: nil
            )
        )
        #expect(getResponse.status.code == 200)
        #expect(getResponse.headerFields[.contentType] == KawarimiAdminHeaders.jsonContentType)
        let decoded = try KawarimiAdminJSONCoding.makeDecoder().decode(
            [RecordedRequest].self,
            from: try #require(getBody)
        )
        #expect(decoded.count == 1)
        #expect(decoded[0].matchedOperationId == "opA")

        let (deleteResponse, deleteBody) = try #require(
            try await handler.handle(
                request: HTTPRequest(method: .delete, scheme: "https", authority: "example.com", path: "/api/__kawarimi/requests"),
                body: nil
            )
        )
        #expect(deleteResponse.status.code == 200)
        #expect(String(data: try #require(deleteBody), encoding: .utf8) == "{}")
        let remaining = await history.requests()
        #expect(remaining.isEmpty)
    }
}
