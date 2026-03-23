import Foundation
import KawarimiHenge
import Testing

/// `URL.host` を HTTP ステータスとして返す（`http://500/` 等）ので、本番と無関係な擬似 URL で検証できる。
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
