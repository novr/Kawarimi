import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime
import Testing

@testable import KawarimiClient

@Suite("KawarimiClientOrchestrationMiddleware", .timeLimit(.minutes(1)))
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

    @Test func errorResponseWithoutNextClearsScenarioState() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "login" }
        )

        var firstResponse = HTTPResponse(status: .ok)
        firstResponse.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] = "locked"
        let responseWithNext = firstResponse
        _ = try await middleware.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login"),
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "login",
            next: { _, _, _ in (responseWithNext, nil) }
        )

        _ = try await middleware.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login"),
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "login",
            next: { _, _, _ in (HTTPResponse(status: .internalServerError), nil) }
        )

        _ = try await middleware.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login"),
            body: nil,
            baseURL: URL(string: "https://example.com/api")!,
            operationID: "login",
            next: { req, _, _ in
                #expect(req.headerFields[HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!] == nil)
                return (HTTPResponse(status: .ok), nil)
            }
        )
    }

    @Test func resetScenarioIdClearsInjectedKawarimiId() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "login" }
        )
        let baseURL = URL(string: "https://example.com/api")!
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
        let nextHeader = HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!
        let kawarimiHeader = HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!

        var firstResponse = HTTPResponse(status: .ok)
        firstResponse.headerFields[nextHeader] = "locked"
        let lockedResponse = firstResponse
        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: baseURL,
            operationID: "login",
            next: { _, _, _ in (lockedResponse, nil) }
        )

        middleware.reset(scenarioId: "login")

        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: baseURL,
            operationID: "login",
            next: { req, _, _ in
                #expect(req.headerFields[kawarimiHeader] == nil)
                return (HTTPResponse(status: .ok), nil)
            }
        )
    }

    @Test func resetAllClearsEveryScenarioState() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { context in
                context.request.path?.contains("login") == true ? "login" : "favorite"
            }
        )
        let baseURL = URL(string: "https://example.com/api")!
        let nextHeader = HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!
        let kawarimiHeader = HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!

        for (path, next) in [("/api/login", "locked"), ("/api/favorites", "done")] {
            var built = HTTPResponse(status: .ok)
            built.headerFields[nextHeader] = next
            let response = built
            _ = try await middleware.intercept(
                HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: path),
                body: nil,
                baseURL: baseURL,
                operationID: "op",
                next: { _, _, _ in (response, nil) }
            )
        }

        middleware.resetAll()

        for path in ["/api/login", "/api/favorites"] {
            _ = try await middleware.intercept(
                HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: path),
                body: nil,
                baseURL: baseURL,
                operationID: "op",
                next: { req, _, _ in
                    #expect(req.headerFields[kawarimiHeader] == nil)
                    return (HTTPResponse(status: .ok), nil)
                }
            )
        }
    }

    @Test func onNextKawarimiIdReportsTransitions() async throws {
        let log = ScenarioTransitionLog()
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "login" },
            onNextKawarimiId: { scenarioId, next in log.append((scenarioId, next)) }
        )
        let baseURL = URL(string: "https://example.com/api")!
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
        let nextHeader = HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!

        var withNextBuilt = HTTPResponse(status: .ok)
        withNextBuilt.headerFields[nextHeader] = "locked"
        let withNext = withNextBuilt
        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: baseURL,
            operationID: "login",
            next: { _, _, _ in (withNext, nil) }
        )

        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: baseURL,
            operationID: "login",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )

        let snapshot = log.snapshot()
        #expect(snapshot.count == 2)
        #expect(snapshot[0].0 == "login")
        #expect(snapshot[0].1 == "locked")
        #expect(snapshot[1].0 == "login")
        #expect(snapshot[1].1 == nil)
    }

    @Test func onNextKawarimiIdNotCalledWithoutScenarioId() async throws {
        let log = ScenarioTransitionLog()
        let middleware = KawarimiClientOrchestrationMiddleware(
            onNextKawarimiId: { scenarioId, next in log.append((scenarioId, next)) }
        )
        let baseURL = URL(string: "https://example.com/api")!
        let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/api/x")

        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: baseURL,
            operationID: "list",
            next: { _, _, _ in (HTTPResponse(status: .ok), nil) }
        )

        #expect(log.snapshot().isEmpty)
    }

    @Test func lastCompletedResponseWinsForConcurrentInFlight() async throws {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in "login" }
        )
        let baseURL = URL(string: "https://example.com/api")!
        let request = HTTPRequest(method: .post, scheme: "https", authority: "example.com", path: "/api/login")
        let nextHeader = HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!
        let kawarimiHeader = HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!
        let gate = InFlightResponseGate()

        async let waitForBoth = gate.waitUntilBothEnteredNext()
        async let first = middleware.intercept(request, body: nil, baseURL: baseURL, operationID: "login") { _, _, _ in
            await gate.enteredNext(task: 1)
            await gate.waitForRelease(task: 1)
            var response = HTTPResponse(status: .ok)
            response.headerFields[nextHeader] = "alpha"
            return (response, nil)
        }
        async let second = middleware.intercept(request, body: nil, baseURL: baseURL, operationID: "login") { _, _, _ in
            await gate.enteredNext(task: 2)
            await gate.waitForRelease(task: 2)
            var response = HTTPResponse(status: .ok)
            response.headerFields[nextHeader] = "beta"
            return (response, nil)
        }

        await waitForBoth
        await gate.release(task: 2)
        await gate.release(task: 1)
        _ = try await second
        _ = try await first

        _ = try await middleware.intercept(
            request,
            body: nil,
            baseURL: baseURL,
            operationID: "login",
            next: { req, _, _ in
                #expect(req.headerFields[kawarimiHeader] == "alpha")
                return (HTTPResponse(status: .ok), nil)
            }
        )
    }
}

private final class ScenarioTransitionLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [(String, String?)] = []

    func append(_ event: (String, String?)) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func snapshot() -> [(String, String?)] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

private actor InFlightResponseGate {
    private var enteredTasks: Set<Int> = []
    private var bothEnteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuations: [Int: CheckedContinuation<Void, Never>] = [:]

    func enteredNext(task: Int) {
        enteredTasks.insert(task)
        if enteredTasks.count == 2 {
            bothEnteredContinuation?.resume()
            bothEnteredContinuation = nil
        }
    }

    func waitUntilBothEnteredNext() async {
        if enteredTasks.count == 2 { return }
        await withCheckedContinuation { continuation in
            bothEnteredContinuation = continuation
        }
    }

    func waitForRelease(task: Int) async {
        await withCheckedContinuation { continuation in
            releaseContinuations[task] = continuation
        }
    }

    func release(task: Int) {
        releaseContinuations.removeValue(forKey: task)?.resume()
    }
}
