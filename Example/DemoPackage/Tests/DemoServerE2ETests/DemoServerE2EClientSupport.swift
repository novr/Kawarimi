#if os(macOS) || os(Linux)
import DemoAPI
import Foundation
import KawarimiClient
import OpenAPIURLSession

enum DemoServerE2EClientSupport {
    static func makeGreetingClient(
        baseURL: URL,
        scenarioId: String,
        onNextKawarimiId: KawarimiScenarioNextHandler? = nil
    ) -> Client {
        let middleware = KawarimiClientOrchestrationMiddleware(
            scenarioIdProvider: { _ in scenarioId },
            onNextKawarimiId: onNextKawarimiId
        )
        return Client(
            serverURL: baseURL,
            transport: URLSessionTransport(),
            middlewares: [middleware]
        )
    }

    static func greetingMessage(from output: Operations.getGreeting.Output) throws -> String {
        switch output {
        case .ok(let ok):
            guard case .json(let body) = ok.body else {
                throw ClientSupportError.unexpectedResponseBody("getGreeting ok body is not json")
            }
            return body.message
        default:
            throw ClientSupportError.unexpectedResponseBody("getGreeting expected .ok, got \(output)")
        }
    }
}

final class ScenarioTransitionLog: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [(scenarioId: String, nextKawarimiId: String?)] = []

    func record(scenarioId: String, nextKawarimiId: String?) {
        lock.lock()
        events.append((scenarioId, nextKawarimiId))
        lock.unlock()
    }

    func snapshot() -> [(scenarioId: String, nextKawarimiId: String?)] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

enum ClientSupportError: Error, CustomStringConvertible {
    case unexpectedResponseBody(String)

    var description: String {
        switch self {
        case .unexpectedResponseBody(let message):
            message
        }
    }
}
#endif
