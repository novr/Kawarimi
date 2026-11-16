import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime

public enum KawarimiStubError: Error, Sendable, Equatable {
    /// No scenario, enabled override, or documented 2xx response exists for this operation.
    case noStub(operationID: String)
}

/// In-process stub for generated OpenAPI clients (`ClientMiddleware`); never calls `next`.
///
/// Resolution order: scenario headers, enabled override, then the operation's lowest documented 2xx response.
/// To reach the network, build the `Client` without this middleware.
public struct KawarimiStubMiddleware: ClientMiddleware {
    public let store: KawarimiConfigStore
    public let responseMap: KawarimiMockResponseResolver.NestedResponseMap
    private let defaultResponsesByOperationID: [String: KawarimiDynamicMockResponse]

    public init(
        store: KawarimiConfigStore,
        responseMap: KawarimiMockResponseResolver.NestedResponseMap,
        endpoints: [any SpecEndpointProviding]
    ) {
        self.store = store
        self.responseMap = responseMap
        var defaults: [String: KawarimiDynamicMockResponse] = [:]
        for endpoint in endpoints where defaults[endpoint.operationId] == nil {
            if let response = Self.defaultSuccessResponse(endpoint.responseList) {
                defaults[endpoint.operationId] = response
            }
        }
        self.defaultResponsesByOperationID = defaults
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        _ = body
        // Client request paths are relative to the server URL, while persisted overrides,
        // scenarios, and `responseMap` keys carry the full path the server would see.
        let requestPath = Self.serverRequestPath(baseURL: baseURL, requestPath: request.path)
        let pathPrefix = await store.pathPrefix
        let overrides = await store.overrides()
        let scenarios = await store.scenarios()

        let scenarioIdField = HTTPField.Name(KawarimiScenarioHeaders.scenarioId)!
        if request.headerFields[scenarioIdField] != nil {
            let kawarimiIdField = HTTPField.Name(KawarimiScenarioHeaders.kawarimiId)!
            let resolution = KawarimiScenarioResolver.resolve(
                scenarios: scenarios,
                overrides: overrides,
                responseMap: responseMap,
                requestPath: requestPath,
                method: request.method,
                scenarioIdHeaderRaw: request.headerFields[scenarioIdField],
                kawarimiIdHeaderRaw: request.headerFields[kawarimiIdField]
            )
            if case .matched(let resolved, let nextKawarimiId, let delayMs, let failureMode) = resolution {
                try await applyMockTiming(failureMode: failureMode, delayMs: delayMs)
                var (response, responseBody) = makeResponse(resolved)
                if let nextKawarimiId {
                    response.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] = nextKawarimiId
                }
                return (response, responseBody)
            }
        }

        let exampleIdField = HTTPField.Name(KawarimiMockRequestHeaders.exampleId)!
        if let override = MockOverrideRequestMatching.primaryEnabledOverride(
            in: overrides,
            requestPath: requestPath,
            method: request.method,
            operationID: operationID,
            pathPrefix: pathPrefix,
            exampleIdHeaderRaw: request.headerFields[exampleIdField]
        ) {
            let resolved = KawarimiDynamicMockResponseResolver.resolve(
                override: override,
                responseMap: responseMap,
                methodUppercased: request.method.rawValue.uppercased()
            )
            try await applyMockTiming(failureMode: override.failureMode, delayMs: override.delayMs)
            return makeResponse(resolved)
        }

        guard let fallback = defaultResponsesByOperationID[operationID] else {
            throw KawarimiStubError.noStub(operationID: operationID)
        }
        return makeResponse(fallback)
    }

    static func serverRequestPath(baseURL: URL, requestPath: String?) -> String {
        let relative = KawarimiRequestPath.pathOnly(requestPath)
        let basePath = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
        let trimmedBase = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        if trimmedBase.isEmpty { return relative }
        return relative == "/" ? trimmedBase : trimmedBase + relative
    }

    static func defaultSuccessResponse(_ responses: [any SpecMockResponseProviding]) -> KawarimiDynamicMockResponse? {
        let successes = responses.filter { (200..<300).contains($0.statusCode) }
        guard let lowest = successes.map(\.statusCode).min() else { return nil }
        let candidates = successes.filter { $0.statusCode == lowest }
        let chosen = candidates.first {
            KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: $0.exampleId)
                == KawarimiExampleIds.defaultResponseMapKey
        } ?? candidates[0]
        return KawarimiDynamicMockResponse(
            statusCode: chosen.statusCode,
            body: chosen.body,
            contentType: chosen.contentType
        )
    }

    private func makeResponse(_ resolved: KawarimiDynamicMockResponse) -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: .init(code: resolved.statusCode))
        if !resolved.contentType.isEmpty {
            response.headerFields[.contentType] = resolved.contentType
        }
        if resolved.body.isEmpty, resolved.contentType.isEmpty {
            return (response, nil)
        }
        return (response, HTTPBody(resolved.body))
    }

    private func applyMockTiming(failureMode: MockFailureMode?, delayMs: Int?) async throws {
        try await MockFailureBehavior.applyIfNeeded(failureMode)
        if let ms = delayMs, ms > 0 {
            try await Task.sleep(for: .milliseconds(ms))
        }
    }
}
