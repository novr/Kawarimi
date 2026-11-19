import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import KawarimiCore
import Testing

/// Uses `URL.host` as the HTTP status (`http://500/`, etc.) so tests avoid real endpoints.
private final class MockKawarimiURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let code = url.host.flatMap { Int($0) } ?? 500
        let body = "Mock error body"
        let response = HTTPURLResponse(
            url: url,
            statusCode: code,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/plain"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: .utf8)!)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func kawarimiAPIErrorDescriptionContainsStatusCodeAndBodySnippet() {
    let err = KawarimiAPIError(statusCode: 503, data: "Service Unavailable — overloaded".data(using: .utf8))
    let desc = err.errorDescription ?? ""
    #expect(desc.contains("503"))
    #expect(desc.contains("Service Unavailable"))
}

@Test func kawarimiAPIErrorDescriptionWithNilData() {
    let err = KawarimiAPIError(statusCode: 404, data: nil)
    #expect(err.errorDescription == "HTTP 404")
}

@Test func kawarimiAPIClientFetchSpecThrowsKawarimiAPIErrorOn5xx() async throws {
    URLProtocol.registerClass(MockKawarimiURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiURLProtocol.self]
    let session = URLSession(configuration: config)
    let baseURL = URL(string: "http://500/")!
    let client = KawarimiAPIClient(baseURL: baseURL, session: session)

    struct DummySpec: Decodable {}
    do {
        _ = try await client.fetchSpec(as: DummySpec.self)
        #expect(Bool(false), "expected KawarimiAPIError")
    } catch let e as KawarimiAPIError {
        #expect(e.statusCode == 500)
        #expect(e.data.flatMap { String(data: $0, encoding: .utf8) }?.contains("Mock error") == true)
    }
}

@Test func kawarimiAPIClientFetchSpecThrowsKawarimiAPIErrorOn4xx() async throws {
    URLProtocol.registerClass(MockKawarimiURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiURLProtocol.self]
    let session = URLSession(configuration: config)
    let baseURL = URL(string: "http://404/")!
    let client = KawarimiAPIClient(baseURL: baseURL, session: session)

    struct DummySpec: Decodable {}
    do {
        _ = try await client.fetchSpec(as: DummySpec.self)
        #expect(Bool(false), "expected KawarimiAPIError")
    } catch let e as KawarimiAPIError {
        #expect(e.statusCode == 404)
    }
}

/// `URL.host` is the `X-Kawarimi-Reload` value (`applied` / `unchanged`); responds with `200` and a JSON override array.
private final class MockKawarimiReloadURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let outcome = url.host ?? "applied"
        let body = """
            [{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":true}]
            """.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: url,
            statusCode: KawarimiAdminRoute.reload.successStatusCode,
            httpVersion: nil,
            headerFields: [
                KawarimiAdminHeaders.reloadOutcome: outcome,
                "Content-Type": KawarimiAdminHeaders.jsonContentType,
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func kawarimiAPIClientReloadParsesReloadOutcomeHeaderAndOverrides() async throws {
    URLProtocol.registerClass(MockKawarimiReloadURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiReloadURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiReloadURLProtocol.self]
    let session = URLSession(configuration: config)

    let appliedClient = KawarimiAPIClient(baseURL: URL(string: "http://applied/")!, session: session)
    let applied = try await appliedClient.reload()
    #expect(applied.result == .applied)
    #expect(applied.overrides.count == 1)
    #expect(applied.overrides[0].path == "/api/greet")

    let unchangedClient = KawarimiAPIClient(baseURL: URL(string: "http://unchanged/")!, session: session)
    let unchanged = try await unchangedClient.reload()
    #expect(unchanged.result == .unchanged)
    #expect(unchanged.overrides.count == 1)
}

/// Responds with `200` and a JSON override array for admin mutation routes.
private final class MockKawarimiMutationURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = """
            [{"path":"/api/items","method":"GET","statusCode":200,"isEnabled":true}]
            """.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: url,
            statusCode: KawarimiAdminRoute.configure.successStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": KawarimiAdminHeaders.jsonContentType]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func kawarimiAPIClientConfigureDecodesOverridesFromResponseBody() async throws {
    URLProtocol.registerClass(MockKawarimiMutationURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiMutationURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiMutationURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1/")!, session: session)
    let override = MockOverride(path: "/api/items", method: "GET", statusCode: 200, isEnabled: true)!
    let overrides = try await client.configure(override: override)
    #expect(overrides.count == 1)
    #expect(overrides[0].path == "/api/items")
}

@Test func kawarimiAPIClientRemoveDecodesOverridesFromResponseBody() async throws {
    URLProtocol.registerClass(MockKawarimiMutationURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiMutationURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiMutationURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1/")!, session: session)
    let override = MockOverride(path: "/api/items", method: "GET", statusCode: 200, isEnabled: true)!
    let overrides = try await client.removeOverride(override: override)
    #expect(overrides.count == 1)
    #expect(overrides[0].path == "/api/items")
}

@Test func kawarimiAPIClientResetDecodesOverridesFromResponseBody() async throws {
    URLProtocol.registerClass(MockKawarimiMutationURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiMutationURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiMutationURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1/")!, session: session)
    let overrides = try await client.reset()
    #expect(overrides.count == 1)
    #expect(overrides[0].path == "/api/items")
}

/// Returns `200` with a non-JSON body so mutation decode should fail.
private final class MockKawarimiMutationInvalidBodyURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = "not a json array".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: url,
            statusCode: KawarimiAdminRoute.configure.successStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/plain"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func kawarimiAPIClientMutationThrowsWhenResponseBodyIsNotOverridesJSON() async throws {
    URLProtocol.registerClass(MockKawarimiMutationInvalidBodyURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiMutationInvalidBodyURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiMutationInvalidBodyURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1/")!, session: session)
    let override = MockOverride(path: "/api/items", method: "GET", statusCode: 200, isEnabled: true)!

    do {
        _ = try await client.configure(override: override)
        #expect(Bool(false), "expected decode failure")
    } catch {
        #expect(Bool(true))
    }
}

/// Returns `200` with a JSON `[KawarimiScenario]` body for `GET …/scenarios`.
private final class MockKawarimiScenariosURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = """
            [{"scenarioId":"login","initial":"step1","cases":[{"kawarimiId":"step1","rowId":"00000000-0000-0000-0000-000000000001","endpoint":{"method":"POST","path":"/api/login"}}]}]
            """.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: url,
            statusCode: KawarimiAdminRoute.scenarios.successStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": KawarimiAdminHeaders.jsonContentType]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func kawarimiAPIClientFetchScenariosDecodesScenarioArray() async throws {
    URLProtocol.registerClass(MockKawarimiScenariosURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiScenariosURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiScenariosURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1/api")!, session: session)
    let scenarios = try await client.fetchScenarios()
    #expect(scenarios.count == 1)
    #expect(scenarios[0].scenarioId == "login")
    #expect(scenarios[0].cases.count == 1)
    #expect(scenarios[0].cases[0].kawarimiId == "step1")
    #expect(scenarios[0].cases[0].rowId.rawValue == "00000000-0000-0000-0000-000000000001")
}

@Test func kawarimiAPIClientFetchScenariosThrowsKawarimiAPIErrorOn5xx() async throws {
    URLProtocol.registerClass(MockKawarimiURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://500/")!, session: session)

    do {
        _ = try await client.fetchScenarios()
        #expect(Bool(false), "expected KawarimiAPIError")
    } catch let e as KawarimiAPIError {
        #expect(e.statusCode == 500)
    }
}

@Test func kawarimiAPIClientAdminURLWithQueryAppendsFilters() {
    let base = URL(string: "http://127.0.0.1:8080/api")!
    let plain = KawarimiAPIClient.adminURLWithQuery(baseURL: base, route: .requests)
    #expect(plain.absoluteString == "http://127.0.0.1:8080/api/__kawarimi/requests")

    let filtered = KawarimiAPIClient.adminURLWithQuery(
        baseURL: base,
        route: .requests,
        operationId: "listWidgets",
        path: "/api/widgets",
        method: "GET"
    )
    let components = URLComponents(url: filtered, resolvingAgainstBaseURL: false)!
    let items = Dictionary(
        uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
    )
    #expect(items["operationId"] == "listWidgets")
    #expect(items["path"] == "/api/widgets")
    #expect(items["method"] == "GET")
}

@Test func kawarimiAPIClientAdminURLWithQueryRoundTripsReservedCharacters() {
    let base = URL(string: "http://127.0.0.1:8080/api")!
    let path = "/api/a&b=c+d e/%41"
    let url = KawarimiAPIClient.adminURLWithQuery(baseURL: base, route: .requests, path: path)
    let raw = url.absoluteString
    let filters = KawarimiRequestHistoryCapture.requestFilters(from: raw.replacingOccurrences(of: "http://127.0.0.1:8080", with: ""))
    #expect(filters.path == path)
}

/// Returns a recorded-request JSON array for GET and captures the request URL.
private final class MockKawarimiFetchRequestsURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastURL: URL?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastURL = request.url
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let sample = RecordedRequest(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000.5),
            method: "GET",
            path: "/api/widgets",
            queryItems: [],
            headers: [:],
            body: nil,
            matchedOperationId: "listWidgets",
            action: .mock,
            responseStatusCode: 200
        )
        let body = try! KawarimiAdminJSONCoding.makeEncoder().encode([sample])
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": KawarimiAdminHeaders.jsonContentType]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Returns `{}` for DELETE and captures the HTTP method.
private final class MockKawarimiClearRequestsURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastMethod: String?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastMethod = request.httpMethod
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: KawarimiAdminRoute.clearRequests.successStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": KawarimiAdminHeaders.jsonContentType]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test func kawarimiAPIClientFetchRequestsDecodesAndBuildsQuery() async throws {
    URLProtocol.registerClass(MockKawarimiFetchRequestsURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiFetchRequestsURLProtocol.self) }
    MockKawarimiFetchRequestsURLProtocol.lastURL = nil

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiFetchRequestsURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1/api")!, session: session)
    let requests = try await client.fetchRequests(operationId: "listWidgets", path: "/api/widgets", method: "GET")
    #expect(requests.count == 1)
    #expect(requests[0].matchedOperationId == "listWidgets")
    let url = try #require(MockKawarimiFetchRequestsURLProtocol.lastURL)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let items = Dictionary(
        uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
    )
    #expect(items["operationId"] == "listWidgets")
    #expect(items["path"] == "/api/widgets")
    #expect(items["method"] == "GET")
}

@Test func kawarimiAPIClientClearRequestsUsesDelete() async throws {
    URLProtocol.registerClass(MockKawarimiClearRequestsURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiClearRequestsURLProtocol.self) }
    MockKawarimiClearRequestsURLProtocol.lastMethod = nil

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiClearRequestsURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1/api")!, session: session)
    try await client.clearRequests()
    #expect(MockKawarimiClearRequestsURLProtocol.lastMethod == "DELETE")
}

@Test func kawarimiAPIClientFetchRequestsThrowsOn404() async throws {
    URLProtocol.registerClass(MockKawarimiURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockKawarimiURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockKawarimiURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://404/")!, session: session)
    do {
        _ = try await client.fetchRequests()
        #expect(Bool(false), "expected KawarimiAPIError")
    } catch let e as KawarimiAPIError {
        #expect(e.statusCode == 404)
    }
}
