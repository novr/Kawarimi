import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime

public struct KawarimiScenarioContext: Sendable {
    public var request: HTTPRequest
    public var operationID: String

    public init(request: HTTPRequest, operationID: String) {
        self.request = request
        self.operationID = operationID
    }
}

public typealias KawarimiScenarioIDProvider = @Sendable (_ context: KawarimiScenarioContext) -> String?

/// Notification-only callback when ``KawarimiScenarioHeaders/nextKawarimiId`` is observed.
public typealias KawarimiScenarioNextHandler = @Sendable (_ scenarioId: String, _ nextKawarimiId: String?) -> Void

/// Injects scenario orchestration headers and tracks per-scenario ``KawarimiScenarioHeaders/kawarimiId`` state.
public struct KawarimiClientOrchestrationMiddleware: ClientMiddleware {
    private let scenarioIdProvider: KawarimiScenarioIDProvider?
    private let onNextKawarimiId: KawarimiScenarioNextHandler?
    private let state: KawarimiScenarioClientState

    public init(
        scenarioIdProvider: KawarimiScenarioIDProvider? = nil,
        onNextKawarimiId: KawarimiScenarioNextHandler? = nil
    ) {
        self.scenarioIdProvider = scenarioIdProvider
        self.onNextKawarimiId = onNextKawarimiId
        self.state = KawarimiScenarioClientState()
    }

    public func reset(scenarioId: String) {
        state.reset(scenarioId: scenarioId)
    }

    public func resetAll() {
        state.resetAll()
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        let scenarioIdField = HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!
        let kawarimiIdField = HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!

        let scenarioId = resolvedScenarioId(
            request: request,
            operationID: operationID,
            scenarioIdField: scenarioIdField
        )

        if let scenarioId, request.headerFields[scenarioIdField] == nil {
            request.headerFields[scenarioIdField] = scenarioId
        }

        if let scenarioId,
           request.headerFields[kawarimiIdField] == nil,
           let kawarimiId = state.kawarimiId(for: scenarioId) {
            request.headerFields[kawarimiIdField] = kawarimiId
        }

        let (response, responseBody) = try await next(request, body, baseURL)

        if let scenarioId {
            let nextField = HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!
            if let nextKawarimiId = KawarimiScenarioTokens.normalize(response.headerFields[nextField]) {
                state.setKawarimiId(nextKawarimiId, for: scenarioId)
                onNextKawarimiId?(scenarioId, nextKawarimiId)
            } else {
                state.reset(scenarioId: scenarioId)
                onNextKawarimiId?(scenarioId, nil)
            }
        }

        return (response, responseBody)
    }

    private func resolvedScenarioId(
        request: HTTPRequest,
        operationID: String,
        scenarioIdField: HTTPField.Name
    ) -> String? {
        if let existing = KawarimiScenarioTokens.normalize(request.headerFields[scenarioIdField]) {
            return existing
        }
        guard let scenarioIdProvider else { return nil }
        let context = KawarimiScenarioContext(request: request, operationID: operationID)
        return scenarioIdProvider(context).flatMap(KawarimiScenarioTokens.normalize)
    }
}

final class KawarimiScenarioClientState: @unchecked Sendable {
    private let lock = NSLock()
    private var kawarimiIdsByScenarioId: [String: String] = [:]

    func kawarimiId(for scenarioId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return kawarimiIdsByScenarioId[scenarioId]
    }

    func setKawarimiId(_ kawarimiId: String, for scenarioId: String) {
        lock.lock()
        defer { lock.unlock() }
        kawarimiIdsByScenarioId[scenarioId] = kawarimiId
    }

    func reset(scenarioId: String) {
        lock.lock()
        defer { lock.unlock() }
        kawarimiIdsByScenarioId.removeValue(forKey: scenarioId)
    }

    func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        kawarimiIdsByScenarioId.removeAll()
    }
}
