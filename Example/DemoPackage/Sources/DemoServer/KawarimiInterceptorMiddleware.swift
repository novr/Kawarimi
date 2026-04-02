#if os(macOS)
import DemoAPI
import KawarimiCore
import Vapor

struct KawarimiInterceptorMiddleware: AsyncMiddleware {
    let store: KawarimiConfigStore

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let path = request.url.path
        guard !KawarimiAdminPath.isManagementRequestPath(path) else {
            return try await next.respond(to: request)
        }

        let method = request.method.rawValue
        let overrides = await store.overrides()

        let hits = MockOverride.sortedForInterceptorTieBreak(
            overrides.filter { ov in
                PathTemplate.matches(actual: path, template: ov.path)
                    && ov.method.rawValue.uppercased() == method.uppercased()
                    && ov.isEnabled
            }
        )
        if hits.count > 1 {
            request.logger.warning(
                "Multiple overrides match \(path) \(method): using first of \(hits.count). Order: \(hits.map { "\($0.path) status=\($0.statusCode) exampleId=\($0.exampleId ?? "nil")" }.joined(separator: " | "))"
            )
        }
        guard let override = hits.first else {
            return try await next.respond(to: request)
        }

        let body: String
        let contentType: String
        if override.hasEffectiveCustomBody, let customBody = override.body {
            body = customBody
            contentType = override.contentType ?? "application/json"
        } else if let entry = KawarimiMockResponseResolver.lookup(
            map: KawarimiSpec.responseMap,
            methodUppercased: method.uppercased(),
            path: override.path,
            statusCode: override.statusCode,
            exampleId: override.exampleId
        ) {
            body = entry.body
            contentType = entry.contentType
        } else {
            return try await next.respond(to: request)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: contentType)
        return Response(
            status: HTTPResponseStatus(statusCode: override.statusCode),
            headers: headers,
            body: .init(string: body)
        )
    }
}
#endif
