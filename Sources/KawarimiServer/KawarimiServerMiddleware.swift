import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime

#if canImport(OSLog)
import OSLog
private let kawarimiServerMiddlewareLog = Logger(subsystem: "Kawarimi", category: "KawarimiServerMiddleware")
private let kawarimiProxyLog = Logger(subsystem: "Kawarimi", category: "KawarimiProxy")
#endif

/// Applies Henge dynamic mock overrides for registered OpenAPI operations (`ServerMiddleware`).
///
/// - ``KawarimiConfigStore`` overrides refresh via `POST …/configure`, `POST …/reload`, or file watch when ``KawarimiConfigStore/startFileWatchIfEnabled()`` is active.
/// - ``responseMap`` is fixed at init (build-time ``KawarimiSpec``); rebuild and re-register middleware after OpenAPI regen.
/// - When ``KawarimiUpstreamSettings/isForwardingEnabled`` is `true`, override misses are forwarded to upstream via raw HTTP instead of calling `next`.
public struct KawarimiServerMiddleware: ServerMiddleware {
    public let store: KawarimiConfigStore
    /// Spec example bodies; not updated until you construct a new middleware instance.
    public let responseMap: KawarimiMockResponseResolver.NestedResponseMap
    private let forwarding: KawarimiUpstreamForwardingConfiguration?
    private let forwarder: KawarimiUpstreamHTTPForwarder?

    public init(
        store: KawarimiConfigStore,
        responseMap: KawarimiMockResponseResolver.NestedResponseMap,
        upstreamSettings: KawarimiUpstreamSettings = .fromEnvironment()
    ) {
        self.store = store
        self.responseMap = responseMap
        self.forwarding = upstreamSettings.forwarding
        if let forwarding = upstreamSettings.forwarding {
            self.forwarder = KawarimiUpstreamHTTPForwarder(
                upstreamOrigin: forwarding.origin,
                proxyDebug: forwarding.proxyDebug
            )
        } else {
            self.forwarder = nil
        }
    }

    /// Test hook: ``forwarding`` requires a resolved origin; ``forwarder`` must target the same origin.
    init(
        store: KawarimiConfigStore,
        responseMap: KawarimiMockResponseResolver.NestedResponseMap,
        forwarding: KawarimiUpstreamForwardingConfiguration,
        forwarder: KawarimiUpstreamHTTPForwarder
    ) {
        self.store = store
        self.responseMap = responseMap
        self.forwarding = forwarding
        self.forwarder = forwarder
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        metadata: ServerRequestMetadata,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        _ = metadata
        let requestPath = KawarimiRequestPath.pathOnly(request.path ?? "")
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
                applyProxyActionHeader(&response, action: KawarimiProxyHeaders.actionMock)
                logProxy(action: KawarimiProxyHeaders.actionMock, path: requestPath, method: request.method)
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
            if let forwarder {
                logProxy(action: KawarimiProxyHeaders.actionForward, path: requestPath, method: request.method)
                var (response, responseBody) = try await forwarder.forward(
                    request: request,
                    body: body,
                    pathPrefix: pathPrefix
                )
                applyProxyActionHeader(&response, action: KawarimiProxyHeaders.actionForward)
                return (response, responseBody)
            }
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
        applyProxyActionHeader(&response, action: KawarimiProxyHeaders.actionMock)
        logProxy(action: KawarimiProxyHeaders.actionMock, path: requestPath, method: request.method)
        return (response, HTTPBody(resolved.body))
    }

    private func applyProxyActionHeader(_ response: inout HTTPResponse, action: String) {
        guard forwarding != nil else { return }
        response.headerFields[HTTPField.Name(KawarimiProxyHeaders.proxyAction)!] = action
    }

    private func logProxy(action: String, path: String, method: HTTPRequest.Method) {
        guard forwarding?.proxyDebug == true else { return }
#if canImport(OSLog)
        kawarimiProxyLog.debug(
            "\(action, privacy: .public) \(method.rawValue, privacy: .public) \(path, privacy: .public)"
        )
#else
        StandardError.write("KawarimiProxy: \(action) \(method.rawValue) \(path)")
#endif
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
