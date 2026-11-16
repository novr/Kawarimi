import Foundation
import HTTPTypes
import KawarimiClient
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiStub

private struct FakeResponse: SpecMockResponseProviding {
    var statusCode: Int
    var contentType: String = "application/json"
    var body: String
    var exampleId: String? = nil
    var summary: String? = nil
    var description: String? = nil
}

private struct FakeEndpoint: SpecEndpointProviding {
    var path: String
    var method: HTTPRequest.Method
    var operationId: String
    var responses: [FakeResponse]
    var responseList: [any SpecMockResponseProviding] { responses }
}

private final class NextFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var called = false
    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return called
    }
    func mark() {
        lock.lock()
        called = true
        lock.unlock()
    }
}

private let baseURL = URL(string: "https://example.com/api")!

private func makeStore(
    overrides: [MockOverride] = [],
    scenarios: [KawarimiScenario]? = nil
) async throws -> (KawarimiConfigStore, URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let configPath = dir.appendingPathComponent("kawarimi.json").path
    let scenarioPath = dir.appendingPathComponent("kawarimi-scenarios.json").path
    try JSONEncoder().encode(KawarimiConfig(overrides: overrides))
        .write(to: URL(fileURLWithPath: configPath), options: .atomic)
    if let scenarios {
        try JSONEncoder().encode(KawarimiScenariosFile(scenarios: scenarios))
            .write(to: URL(fileURLWithPath: scenarioPath), options: .atomic)
    }
    let store = try KawarimiConfigStore(configPath: configPath, pathPrefix: "/api", scenariosPath: scenarioPath)
    return (store, dir)
}

private func collect(_ body: HTTPBody?) async throws -> String? {
    guard let body else { return nil }
    return try await String(collecting: body, upTo: 1024 * 1024)
}

private func failingNext(_ flag: NextFlag) -> @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) {
    { _, _, _ in
        flag.mark()
        return (HTTPResponse(status: .ok), nil)
    }
}

@Suite("KawarimiStubMiddleware", .timeLimit(.minutes(1)))
struct KawarimiStubMiddlewareTests {
    @Test func relativeClientPathMatchesPrefixedOverrideWithoutCallingNext() async throws {
        let (store, dir) = try await makeStore(overrides: [
            MockOverride(
                path: "/api/greet",
                method: .get,
                statusCode: 201,
                body: "{\"mocked\":true}",
                contentType: "application/json"
            ),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let middleware = KawarimiStubMiddleware(store: store, responseMap: [:], endpoints: [])
        let flag = NextFlag()

        let (response, body) = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/greet?lang=ja"),
            body: nil,
            baseURL: baseURL,
            operationID: "getGreeting",
            next: failingNext(flag)
        )

        #expect(!flag.value)
        #expect(response.status.code == 201)
        #expect(response.headerFields[.contentType] == "application/json")
        #expect(try await collect(body) == "{\"mocked\":true}")
    }

    @Test func overrideMatchesByOperationIDAndExampleHeaderNarrowsChoice() async throws {
        let (store, dir) = try await makeStore(overrides: [
            MockOverride(name: "getGreeting", path: "/typo", method: .get, statusCode: 200, exampleId: "formal"),
            MockOverride(name: "getGreeting", path: "/typo", method: .get, statusCode: 200, exampleId: "casual"),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let responseMap: KawarimiMockResponseResolver.NestedResponseMap = [
            "GET:/typo": [
                200: [
                    "formal": (body: "{\"message\":\"Good day\"}", contentType: "application/json"),
                    "casual": (body: "{\"message\":\"Hi\"}", contentType: "application/json"),
                ],
            ],
        ]
        let middleware = KawarimiStubMiddleware(store: store, responseMap: responseMap, endpoints: [])
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/greet")
        request.headerFields[HTTPField.Name(KawarimiMockRequestHeaders.exampleId)!] = "formal"

        let (response, body) = try await middleware.intercept(
            request,
            body: nil,
            baseURL: baseURL,
            operationID: "getGreeting",
            next: failingNext(NextFlag())
        )

        #expect(response.status.code == 200)
        #expect(try await collect(body) == "{\"message\":\"Good day\"}")
    }

    @Test func specDefaultIsChosenByOperationIDNotPathTemplate() async throws {
        let (store, dir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let endpoints: [any SpecEndpointProviding] = [
            FakeEndpoint(
                path: "/api/items/{id}",
                method: .get,
                operationId: "getItem",
                responses: [FakeResponse(statusCode: 200, body: "{\"kind\":\"item\"}")]
            ),
            FakeEndpoint(
                path: "/api/items/search",
                method: .get,
                operationId: "searchItems",
                responses: [
                    FakeResponse(statusCode: 404, body: "{\"error\":true}"),
                    FakeResponse(statusCode: 201, body: "{\"kind\":\"created\"}"),
                    FakeResponse(statusCode: 200, body: "{\"kind\":\"named\"}", exampleId: "named"),
                    FakeResponse(statusCode: 200, body: "{\"kind\":\"search\"}"),
                ]
            ),
        ]
        let middleware = KawarimiStubMiddleware(store: store, responseMap: [:], endpoints: endpoints)

        let (response, body) = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/items/search"),
            body: nil,
            baseURL: baseURL,
            operationID: "searchItems",
            next: failingNext(NextFlag())
        )

        #expect(response.status.code == 200)
        #expect(try await collect(body) == "{\"kind\":\"search\"}")
    }

    @Test func emptySpecResponseOmitsBodyAndContentType() async throws {
        let (store, dir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let endpoints: [any SpecEndpointProviding] = [
            FakeEndpoint(
                path: "/api/items/{id}",
                method: .delete,
                operationId: "deleteItem",
                responses: [FakeResponse(statusCode: 204, contentType: "", body: "")]
            ),
        ]
        let middleware = KawarimiStubMiddleware(store: store, responseMap: [:], endpoints: endpoints)

        let (response, body) = try await middleware.intercept(
            HTTPRequest(method: .delete, scheme: nil, authority: nil, path: "/items/1"),
            body: nil,
            baseURL: baseURL,
            operationID: "deleteItem",
            next: failingNext(NextFlag())
        )

        #expect(response.status.code == 204)
        #expect(response.headerFields[.contentType] == nil)
        #expect(body == nil)
    }

    @Test func missingSuccessResponseThrowsNoStubWithoutCallingNext() async throws {
        let (store, dir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let endpoints: [any SpecEndpointProviding] = [
            FakeEndpoint(
                path: "/api/broken",
                method: .get,
                operationId: "broken",
                responses: [FakeResponse(statusCode: 500, body: "{}")]
            ),
        ]
        let middleware = KawarimiStubMiddleware(store: store, responseMap: [:], endpoints: endpoints)
        let flag = NextFlag()

        await #expect(throws: KawarimiStubError.noStub(operationID: "broken")) {
            _ = try await middleware.intercept(
                HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/broken"),
                body: nil,
                baseURL: baseURL,
                operationID: "broken",
                next: failingNext(flag)
            )
        }
        #expect(!flag.value)
    }

    @Test func connectionCloseOverrideThrows() async throws {
        let (store, dir) = try await makeStore(overrides: [
            MockOverride(path: "/api/greet", method: .get, statusCode: 200, body: "{}", failureMode: .connectionClose),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let middleware = KawarimiStubMiddleware(store: store, responseMap: [:], endpoints: [])

        await #expect(throws: KawarimiMockFailureError.connectionClose) {
            _ = try await middleware.intercept(
                HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/greet"),
                body: nil,
                baseURL: baseURL,
                operationID: "getGreeting",
                next: failingNext(NextFlag())
            )
        }
    }

    @Test func delayIsInterruptedByCancellation() async throws {
        let (store, dir) = try await makeStore(overrides: [
            MockOverride(path: "/api/greet", method: .get, statusCode: 200, body: "{}", delayMs: 60_000),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }
        let middleware = KawarimiStubMiddleware(store: store, responseMap: [:], endpoints: [])

        let task = Task {
            try await middleware.intercept(
                HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/greet"),
                body: nil,
                baseURL: baseURL,
                operationID: "getGreeting",
                next: failingNext(NextFlag())
            )
        }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test func scenarioRoundTripWithOuterOrchestrationMiddleware() async throws {
        let lockedRow = MockOverrideRowID.generate()
        let okRow = MockOverrideRowID.generate()
        let (store, dir) = try await makeStore(
            overrides: [
                MockOverride(rowId: lockedRow, path: "/api/login", method: .post, statusCode: 401, body: "{\"step\":1}", contentType: "application/json"),
                MockOverride(rowId: okRow, path: "/api/login", method: .post, statusCode: 200, isEnabled: false, body: "{\"step\":2}", contentType: "application/json"),
            ],
            scenarios: [
                KawarimiScenario(
                    scenarioId: "login",
                    initial: "start",
                    cases: [
                        .init(kawarimiId: "start", next: "retry", rowId: lockedRow, endpoint: .init(method: "POST", path: "/api/login")),
                        .init(kawarimiId: "retry", next: nil, rowId: okRow, endpoint: .init(method: "POST", path: "/api/login")),
                    ]
                ),
            ]
        )
        defer { try? FileManager.default.removeItem(at: dir) }
        let stub = KawarimiStubMiddleware(store: store, responseMap: [:], endpoints: [])
        let orchestration = KawarimiClientOrchestrationMiddleware(scenarioIdProvider: { _ in "login" })
        let flag = NextFlag()

        @Sendable func send() async throws -> (HTTPResponse, HTTPBody?) {
            try await orchestration.intercept(
                HTTPRequest(method: .post, scheme: nil, authority: nil, path: "/login"),
                body: nil,
                baseURL: baseURL,
                operationID: "login",
                next: { request, body, url in
                    try await stub.intercept(request, body: body, baseURL: url, operationID: "login", next: failingNext(flag))
                }
            )
        }

        let (first, firstBody) = try await send()
        #expect(first.status.code == 401)
        #expect(first.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] == "retry")
        #expect(try await collect(firstBody) == "{\"step\":1}")

        let (second, secondBody) = try await send()
        #expect(second.status.code == 200)
        #expect(second.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] == nil)
        #expect(try await collect(secondBody) == "{\"step\":2}")

        let (third, _) = try await send()
        #expect(third.status.code == 401)
        #expect(!flag.value)
    }

    @Test func serverRequestPathJoinsBaseURLPath() {
        #expect(KawarimiStubMiddleware.serverRequestPath(baseURL: URL(string: "https://h/api")!, requestPath: "/greet") == "/api/greet")
        #expect(KawarimiStubMiddleware.serverRequestPath(baseURL: URL(string: "https://h/api/")!, requestPath: "/greet") == "/api/greet")
        #expect(KawarimiStubMiddleware.serverRequestPath(baseURL: URL(string: "https://h")!, requestPath: "/greet?q=1") == "/greet")
        #expect(KawarimiStubMiddleware.serverRequestPath(baseURL: URL(string: "https://h/api")!, requestPath: nil) == "/api")
    }
}
