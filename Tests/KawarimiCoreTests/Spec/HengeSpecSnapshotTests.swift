import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes
import KawarimiCore
import Testing

@Test(.timeLimit(.minutes(1))) func hengeSpecSnapshotDecodesWireJSONIncludingDELETE() throws {
    guard let url = Bundle.module.url(forResource: "henge-spec-snapshot", withExtension: "json", subdirectory: "Fixtures") else {
        Issue.record("henge-spec-snapshot.json not found in test resources")
        return
    }
    let data = try Data(contentsOf: url)
    let snapshot = try JSONDecoder().decode(HengeSpecSnapshot.self, from: data)

    #expect(snapshot.meta.title == "GreetingService")
    #expect(snapshot.meta.apiPathPrefix == "/api")
    #expect(snapshot.securitySchemeCatalog == nil)

    let deleteItem = try #require(snapshot.endpoints.first { $0.operationId == "deleteItem" })
    #expect(deleteItem.method == .delete)
    #expect(deleteItem.path == "/api/items/{id}")
    #expect(deleteItem.tags == ["Items"])
    let pathParam = try #require(deleteItem.parameters?.first)
    #expect(pathParam.location == .path)
    #expect(pathParam.name == "id")
    #expect(pathParam.required)

    let noContent = try #require(deleteItem.responseList.first { $0.statusCode == 204 })
    #expect(noContent.body == "{}")
    #expect(noContent.contentType == "application/json")
}

private final class MockHengeSpecURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        guard let fixtureURL = Bundle.module.url(
            forResource: "henge-spec-snapshot",
            withExtension: "json",
            subdirectory: "Fixtures"
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        let fixtureData = (try? Data(contentsOf: fixtureURL)) ?? Data()
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: fixtureData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Test(.timeLimit(.minutes(1))) func kawarimiAPIClientFetchHengeSpecDecodesSnapshot() async throws {
    URLProtocol.registerClass(MockHengeSpecURLProtocol.self)
    defer { URLProtocol.unregisterClass(MockHengeSpecURLProtocol.self) }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockHengeSpecURLProtocol.self]
    let session = URLSession(configuration: config)
    let client = KawarimiAPIClient(baseURL: URL(string: "http://127.0.0.1:8080/api")!, session: session)

    let snapshot = try await client.fetchHengeSpec()
    #expect(snapshot.endpoints.contains { $0.operationId == "deleteItem" && $0.method == .delete })
}
