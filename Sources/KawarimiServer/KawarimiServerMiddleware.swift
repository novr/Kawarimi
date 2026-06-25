import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime

#if canImport(OSLog)
import OSLog
private let kawarimiServerMiddlewareLog = Logger(subsystem: "Kawarimi", category: "KawarimiServerMiddleware")
#endif

/// Applies Henge dynamic mock overrides for registered OpenAPI operations (`ServerMiddleware`).
///
/// - ``KawarimiConfigStore`` overrides refresh via `POST …/configure`, `POST …/reload`, or file watch when ``KawarimiConfigStore/startFileWatchIfEnabled()`` is active.
/// - ``responseMap`` is fixed at init (build-time ``KawarimiSpec``); rebuild and re-register middleware after OpenAPI regen.
public struct KawarimiServerMiddleware: ServerMiddleware {
    public let store: KawarimiConfigStore
    /// Spec example bodies; not updated until you construct a new middleware instance.
    public let responseMap: KawarimiMockResponseResolver.NestedResponseMap

    public init(
        store: KawarimiConfigStore,
        responseMap: KawarimiMockResponseResolver.NestedResponseMap
    ) {
        self.store = store
        self.responseMap = responseMap
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        metadata: ServerRequestMetadata,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        _ = metadata
        let requestPath = KawarimiRequestPath.pathOnly(request.path)
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
            if case .matched(let resolved, let nextKawarimiId, let delayMs) = resolution {
                if let ms = delayMs, ms > 0 {
                    try await Task.sleep(for: .milliseconds(ms))
                }
                var response = HTTPResponse(status: .init(code: resolved.statusCode))
                response.headerFields[.contentType] = resolved.contentType
                if let nextKawarimiId {
                    response.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] = nextKawarimiId
                }
                return (response, HTTPBody(resolved.body))
            }
            if case .fallback(let reason) = resolution {
                logScenarioFallback(reason: reason, requestPath: requestPath, method: request.method)
            }
        }

        let exampleIdField = HTTPField.Name(KawarimiMockRequestHeaders.exampleId)!
        let exampleIdHeader = request.headerFields[exampleIdField]
        let hits = MockOverrideRequestMatching.matchingEnabledOverrides(
            in: overrides,
            requestPath: requestPath,
            method: request.method,
            operationID: operationID,
            pathPrefix: pathPrefix,
            exampleIdHeaderRaw: exampleIdHeader
        )
        if hits.count > 1 {
            let message =
                "Multiple overrides match \(requestPath) \(request.method.rawValue): using first of \(hits.count)"
#if canImport(OSLog)
            kawarimiServerMiddlewareLog.warning("\(message, privacy: .public)")
#else
            StandardError.write("KawarimiServerMiddleware: \(message)")
#endif
        }
        guard let override = hits.first else {
            return try await next(request, body, metadata)
        }

        let resolved = KawarimiDynamicMockResponseResolver.resolve(
            override: override,
            responseMap: responseMap,
            methodUppercased: request.method.rawValue.uppercased()
        )
        if let ms = override.delayMs, ms > 0 {
            try await Task.sleep(for: .milliseconds(ms))
        }
        var response = HTTPResponse(status: .init(code: resolved.statusCode))
        response.headerFields[.contentType] = resolved.contentType
        return (response, HTTPBody(resolved.body))
    }

    private func logScenarioFallback(
        reason: KawarimiScenarioResolutionReason,
        requestPath: String,
        method: HTTPRequest.Method
    ) {
        let message =
            "Scenario fallback (\(reason.rawValue)) for \(requestPath) \(method.rawValue); using standard override resolution"
#if canImport(OSLog)
        kawarimiServerMiddlewareLog.debug("\(message, privacy: .public)")
#else
        StandardError.write("KawarimiServerMiddleware: \(message)")
#endif
    }
}
