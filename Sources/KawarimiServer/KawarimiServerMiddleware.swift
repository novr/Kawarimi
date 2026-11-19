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
/// - Override miss with upstream enabled must not call ``next`` (would run generated stubs, not upstream).
/// - Optional ``historyStore`` records Spy history; when `nil`, request bodies are left untouched.
public struct KawarimiServerMiddleware: ServerMiddleware {
    public let store: KawarimiConfigStore
    /// Spec example bodies; not updated until you construct a new middleware instance.
    public let responseMap: KawarimiMockResponseResolver.NestedResponseMap
    public let historyStore: KawarimiRequestHistoryStore?
    private let forwarding: KawarimiUpstreamForwardingConfiguration?
    private let forwarder: KawarimiUpstreamHTTPForwarder?

    public init(
        store: KawarimiConfigStore,
        responseMap: KawarimiMockResponseResolver.NestedResponseMap,
        upstreamSettings: KawarimiUpstreamSettings = .fromEnvironment(),
        historyStore: KawarimiRequestHistoryStore? = nil
    ) {
        self.store = store
        self.responseMap = responseMap
        self.historyStore = historyStore
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
        forwarder: KawarimiUpstreamHTTPForwarder,
        historyStore: KawarimiRequestHistoryStore? = nil
    ) {
        self.store = store
        self.responseMap = responseMap
        self.historyStore = historyStore
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
        let receivedAt = Date()
        let rawPath = request.path ?? ""
        let requestPath = KawarimiRequestPath.pathOnly(rawPath)
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
                let bodyText = await captureMockBodyPrefixIfRecording(body)
                await recordHistory(
                    request: request,
                    receivedAt: receivedAt,
                    bodyText: bodyText,
                    operationID: operationID,
                    action: .mock,
                    responseStatusCode: failureMode == nil ? resolved.statusCode : nil
                )
                try await applyMockTiming(failureMode: failureMode, delayMs: delayMs)
                var response = HTTPResponse(status: .init(code: resolved.statusCode))
                applyContentType(&response, resolved.contentType)
                if let nextKawarimiId {
                    response.headerFields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] = nextKawarimiId
                }
                applyProxyActionHeader(&response, action: KawarimiProxyHeaders.actionMock)
                logProxy(action: KawarimiProxyHeaders.actionMock, path: requestPath, method: request.method)
                return (response, mockBody(resolved))
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
                return try await forwardOrPassthrough(
                    request: request,
                    body: body,
                    receivedAt: receivedAt,
                    operationID: operationID,
                    action: .forward
                ) { bodyToSend in
                    var (response, responseBody) = try await forwarder.forward(
                        request: request,
                        body: bodyToSend,
                        pathPrefix: pathPrefix
                    )
                    applyProxyActionHeader(&response, action: KawarimiProxyHeaders.actionForward)
                    return (response, responseBody)
                }
            }
            return try await forwardOrPassthrough(
                request: request,
                body: body,
                receivedAt: receivedAt,
                operationID: operationID,
                action: .passthrough
            ) { bodyToSend in
                try await next(request, bodyToSend, metadata)
            }
        }

        let resolved = KawarimiDynamicMockResponseResolver.resolve(
            override: override,
            responseMap: responseMap,
            methodUppercased: request.method.rawValue.uppercased()
        )
        let bodyText = await captureMockBodyPrefixIfRecording(body)
        await recordHistory(
            request: request,
            receivedAt: receivedAt,
            bodyText: bodyText,
            operationID: operationID,
            action: .mock,
            responseStatusCode: override.failureMode == nil ? resolved.statusCode : nil
        )
        try await applyMockTiming(failureMode: override.failureMode, delayMs: override.delayMs)
        var response = HTTPResponse(status: .init(code: resolved.statusCode))
        applyContentType(&response, resolved.contentType)
        applyProxyActionHeader(&response, action: KawarimiProxyHeaders.actionMock)
        logProxy(action: KawarimiProxyHeaders.actionMock, path: requestPath, method: request.method)
        return (response, mockBody(resolved))
    }

    private func forwardOrPassthrough(
        request: HTTPRequest,
        body: HTTPBody?,
        receivedAt: Date,
        operationID: String,
        action: RecordedProxyAction,
        send: @Sendable (HTTPBody?) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let bodyToSend: HTTPBody?
        let observer: KawarimiHTTPBodyPrefixObserver?
        if historyStore != nil {
            (bodyToSend, observer) = KawarimiHTTPBodyPrefixObserver.tee(body)
        } else {
            bodyToSend = body
            observer = nil
        }
        do {
            let (response, responseBody) = try await send(bodyToSend)
            await recordHistory(
                request: request,
                receivedAt: receivedAt,
                bodyText: observer?.capturedBody(),
                operationID: operationID,
                action: action,
                responseStatusCode: response.status.code
            )
            return (response, responseBody)
        } catch {
            await recordHistory(
                request: request,
                receivedAt: receivedAt,
                bodyText: observer?.capturedBody(),
                operationID: operationID,
                action: action,
                responseStatusCode: nil
            )
            throw error
        }
    }

    /// Spy must not change mock behavior: a failed or aborted body read only loses the recorded body.
    private func captureMockBodyPrefixIfRecording(_ body: HTTPBody?) async -> String? {
        guard historyStore != nil, let body else { return nil }
        let maxBytes = KawarimiRequestHistoryCapture.maxBodyUTF8Bytes
        var collected = Data()
        do {
            for try await chunk in body {
                collected.append(contentsOf: chunk.prefix(maxBytes - collected.count))
                if collected.count >= maxBytes { break }
            }
        } catch {
            return nil
        }
        return KawarimiRequestHistoryCapture.utf8Prefix(from: collected)
    }

    private func recordHistory(
        request: HTTPRequest,
        receivedAt: Date,
        bodyText: String?,
        operationID: String,
        action: RecordedProxyAction,
        responseStatusCode: Int?
    ) async {
        guard let historyStore else { return }
        let rawPath = request.path ?? ""
        let pathOnly = KawarimiRequestPath.pathOnly(rawPath)
        if KawarimiAdminPath.isManagementRequestPath(pathOnly) {
            return
        }
        let recorded = RecordedRequest(
            id: UUID(),
            timestamp: receivedAt,
            method: request.method.rawValue,
            path: pathOnly,
            queryItems: KawarimiRequestHistoryCapture.queryItems(from: rawPath),
            headers: KawarimiRequestHistoryCapture.normalizedHeaders(from: request.headerFields),
            body: bodyText,
            matchedOperationId: operationID,
            action: action,
            responseStatusCode: responseStatusCode
        )
        await historyStore.record(recorded)
    }

    private func applyProxyActionHeader(_ response: inout HTTPResponse, action: String) {
        guard forwarding != nil else { return }
        response.headerFields[HTTPField.Name(KawarimiProxyHeaders.proxyAction)!] = action
    }

    private func applyContentType(_ response: inout HTTPResponse, _ contentType: String) {
        guard !contentType.isEmpty else { return }
        response.headerFields[.contentType] = contentType
    }

    private func mockBody(_ resolved: KawarimiDynamicMockResponse) -> HTTPBody? {
        if resolved.body.isEmpty, resolved.contentType.isEmpty {
            return nil
        }
        return HTTPBody(resolved.body)
    }

    private func applyMockTiming(failureMode: MockFailureMode?, delayMs: Int?) async throws {
        try await MockFailureBehavior.applyIfNeeded(failureMode)
        if let ms = delayMs, ms > 0 {
            try await Task.sleep(for: .milliseconds(ms))
        }
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
