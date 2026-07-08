import Foundation
import HTTPTypes
import KawarimiCore
import Testing

@testable import KawarimiServer

@Suite("KawarimiAdminHTTPHandler")
struct KawarimiAdminHTTPHandlerTests {
    private func makeStore(pathPrefix: String = "/api") throws -> (KawarimiConfigStore, URL) {
        let configURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{\"overrides\":[]}".utf8).write(to: configURL)
        let store = try KawarimiConfigStore(configPath: configURL.path, pathPrefix: pathPrefix)
        return (store, configURL)
    }

    private func adminRequest(
        path: String,
        method: HTTPRequest.Method = .get
    ) -> HTTPRequest {
        HTTPRequest(method: method, scheme: "https", authority: "example.com", path: path)
    }

    @Test func unknownAdminSegmentReturnsNil() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let request = adminRequest(path: "/api/__kawarimi/unknown", method: .get)
        let result = try await handler.handle(request: request, body: nil)
        #expect(result == nil)
    }

    @Test func managementLikePathWithWrongPrefixReturnsNil() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let request = adminRequest(path: "/wrong/__kawarimi/status", method: .get)
        let result = try await handler.handle(request: request, body: nil)
        #expect(result == nil)
    }

    @Test func nonAdminPathReturnsNil() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let request = adminRequest(path: "/api/greet", method: .get)
        let result = try await handler.handle(request: request, body: nil)
        #expect(result == nil)
    }

    @Test func statusReturnsOverridesJSON() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        try await store.configure(
            MockOverride(
                path: "/api/widgets",
                method: .get,
                statusCode: 200,
                body: "{\"ok\":true}",
                contentType: "application/json"
            )
        )

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let request = adminRequest(path: "/api/__kawarimi/status", method: .get)
        let (response, bodyData) = try #require(try await handler.handle(request: request, body: nil))
        #expect(response.status.code == 200)
        #expect(response.headerFields[.contentType] == KawarimiAdminHeaders.jsonContentType)
        let body = try #require(bodyData)
        let overrides = try JSONDecoder().decode([MockOverride].self, from: body)
        #expect(overrides.count == 1)
        #expect(overrides[0].path == "/api/widgets")
    }

    @Test func configureSuccess() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let configureBody = Data(
            """
            {"path":"/api/widgets","method":"GET","statusCode":201,"isEnabled":true}
            """.utf8
        )
        let request = adminRequest(path: "/api/__kawarimi/configure", method: .post)
        let (response, bodyData) = try #require(try await handler.handle(request: request, body: configureBody))
        #expect(response.status.code == 200)
        let overrides = try JSONDecoder().decode([MockOverride].self, from: try #require(bodyData))
        #expect(overrides.count == 1)
        #expect(overrides[0].statusCode == 201)
    }

    @Test func configureRejectsInvalidJSON() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let request = adminRequest(path: "/api/__kawarimi/configure", method: .post)
        let (response, bodyData) = try #require(
            try await handler.handle(request: request, body: Data("{not json}".utf8))
        )
        #expect(response.status.code == 400)
        let text = String(data: try #require(bodyData), encoding: .utf8) ?? ""
        #expect(text.contains("Invalid JSON body"))
    }

    @Test func configureRejectsOversizedBody() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let oversized = String(repeating: "x", count: MockOverride.maxBodyLength + 1)
        let configureBody = Data(
            """
            {"path":"/api/widgets","method":"GET","statusCode":200,"isEnabled":true,\
            "body":"\(oversized)","contentType":"application/json"}
            """.utf8
        )
        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let request = adminRequest(path: "/api/__kawarimi/configure", method: .post)
        let (response, _) = try #require(try await handler.handle(request: request, body: configureBody))
        #expect(response.status.code == 413)
    }

    @Test func removeSuccess() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        try await store.configure(
            MockOverride(
                path: "/api/widgets",
                method: .get,
                statusCode: 200,
                isEnabled: true
            )
        )

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let removeBody = Data(
            """
            {"path":"/api/widgets","method":"GET","statusCode":200,"isEnabled":true}
            """.utf8
        )
        let request = adminRequest(path: "/api/__kawarimi/remove", method: .post)
        let (response, bodyData) = try #require(try await handler.handle(request: request, body: removeBody))
        #expect(response.status.code == 200)
        let overrides = try JSONDecoder().decode([MockOverride].self, from: try #require(bodyData))
        #expect(overrides.isEmpty)
    }

    @Test func reloadSetsHeader() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { Data("{}".utf8) })
        let request = adminRequest(path: "/api/__kawarimi/reload", method: .post)
        let (response, _) = try #require(try await handler.handle(request: request, body: nil))
        #expect(response.status.code == 200)
        #expect(
            response.headerFields[KawarimiAdminHeaders.reloadOutcomeField] == "unchanged"
        )
    }

    @Test func specReturnsInjectedWireData() async throws {
        let (store, configURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: configURL) }

        let wire = Data("{\"meta\":{\"apiPathPrefix\":\"/api\"}}".utf8)
        let handler = KawarimiAdminHTTPHandler(store: store, specWireData: { wire })
        let request = adminRequest(path: "/api/__kawarimi/spec", method: .get)
        let (response, bodyData) = try #require(try await handler.handle(request: request, body: nil))
        #expect(response.status.code == 200)
        #expect(bodyData == wire)
    }
}
