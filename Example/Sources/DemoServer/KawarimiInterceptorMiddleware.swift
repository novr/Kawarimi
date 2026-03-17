import DemoAPI
import KawarimiCore
import Vapor

struct KawarimiInterceptorMiddleware: AsyncMiddleware {
    let store: KawarimiConfigStore

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let path = request.url.path
        guard !path.hasPrefix("/__kawarimi") else {
            return try await next.respond(to: request)
        }

        let method = request.method.rawValue
        let mockId = request.headers.first(name: "x-kawarimi-mockId")
        let overrides = await store.overrides()

        let match = overrides.first { ov in
            ov.path == path
                && ov.method.uppercased() == method.uppercased()
                && ov.isEnabled
                && (mockId == nil || ov.mockId == mockId)
        }

        guard let override = match else {
            return try await next.respond(to: request)
        }

        let body: String
        let contentType: String
        if override.hasEffectiveCustomBody, let customBody = override.body {
            body = customBody
            contentType = override.contentType ?? "application/json"
        } else if let responses = KawarimiSpec.responseMap["\(method.uppercased()):\(path)"],
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
