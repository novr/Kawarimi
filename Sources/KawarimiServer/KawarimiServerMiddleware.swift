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
/// - ``KawarimiConfigStore`` overrides refresh via `POST …/configure` (not by watching `kawarimi.json` on disk).
/// - ``responseMap`` is fixed at init; re-register middleware after OpenAPI regen.
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
        var response = HTTPResponse(status: .init(code: resolved.statusCode))
        response.headerFields[.contentType] = resolved.contentType
        return (response, HTTPBody(resolved.body))
    }
}
