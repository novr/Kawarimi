import DemoAPI
import KawarimiCore
import Vapor

struct KawarimiInterceptorMiddleware: AsyncMiddleware {
    let store: KawarimiConfigStore

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let path = request.url.path
        // 管理 API はパスセグメントが `__kawarimi` と完全一致するときのみ（`foo__kawarimi` 等は除外）
        guard !KawarimiAdminPath.isManagementRequestPath(path) else {
            return try await next.respond(to: request)
        }

        let method = request.method.rawValue
        let mockId = request.headers.first(name: "x-kawarimi-mockId")
        let overrides = await store.overrides()

        let matches = overrides.filter { ov in
            PathTemplate.matches(actual: path, template: ov.path)
                && ov.method.uppercased() == method.uppercased()
                && ov.isEnabled
                && (mockId == nil || ov.mockId == mockId)
        }
        if matches.count > 1 {
            request.logger.warning("Multiple overrides match \(path) \(method): using first of \(matches.count). Paths: \(matches.map(\.path).joined(separator: ", "))")
        }
        guard let override = matches.first else {
            return try await next.respond(to: request)
        }

        let body: String
        let contentType: String
        if override.hasEffectiveCustomBody, let customBody = override.body {
            body = customBody
            contentType = override.contentType ?? "application/json"
        } else if let responses = KawarimiSpec.responseMap["\(method.uppercased()):\(override.path)"],
                  let entry = responses[override.statusCode] {
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
