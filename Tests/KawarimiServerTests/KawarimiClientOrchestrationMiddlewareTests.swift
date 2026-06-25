import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiServer

@Suite("KawarimiClientOrchestrationMiddleware")
struct KawarimiClientOrchestrationMiddlewareTests {
    @Test func initialRequestSendsScenarioIdOnly() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "login" }
        )
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
        let (outRequest, _) = try await middleware.intercept(
            request,
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "login",
            next: { req, _, _ in
                #expect(req.headerFields[HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!] == "login")
                #expect(req.headerFields[HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!] == nil)
                return (HTTPResponse(status: .ok), nil)
            }
        )
        _ = outRequest
    }

    @Test func requestHeaderOverridesProvider() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "from-provider" }
        )
        var request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/x")
        request.headerFields[HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!] = "from-request"
        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "list",
            next: { req, _, _ in
                #expect(req.headerFields[HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!] == "from-request")
                return (HTTPResponse(status: .ok), nil)
            }
        )
    }

    @Test func continuationInjectsStoredKawarimiId() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "login" }
        )

        let firstRequest = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
        var firstResponse = HTTPResponse(status: .ok)
        firstResponse.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] = "locked"
        let responseWithNext = firstResponse
        _ = try await middleware.intercept(
            firstRequest,
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "login",
            next: { _, _, _ in (responseWithNext, nil) }
        )

        let secondRequest = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
        _ = try await middleware.intercept(
            secondRequest,
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "login",
            next: { req, _, _ in
                #expect(req.headerFields[HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!] == "locked")
                return (HTTPResponse(status: .ok), nil)
            }
        )
    }

    @Test func terminalResponseClearsScenarioState() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "favorite" }
        )

        var firstResponse = HTTPResponse(status: .created)
        firstResponse.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] = "done"
        let responseWithNext = firstResponse
        _ = try await middleware.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/favorites"),
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "addFavorite",
            next: { _, _, _ in (responseWithNext, nil) }
        )

        _ = try await middleware.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/favorites"),
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "addFavorite",
            next: { req, _, _ in
                #expect(req.headerFields[HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!] == "done")
                return (HTTPResponse(status: .created), nil)
            }
        )

        _ = try await middleware.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/favorites"),
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "addFavorite",
            next: { req, _, _ in
                #expect(req.headerFields[HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!] == nil)
                return (HTTPResponse(status: .created), nil)
            }
        )
    }
}
