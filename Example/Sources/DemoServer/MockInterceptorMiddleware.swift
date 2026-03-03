import DemoAPI
import KawarimiCore
import Vapor

struct MockInterceptorMiddleware: AsyncMiddleware {
    let store: MockConfigStore

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

        guard let override = match,
              let responses = KawarimiSpec.responseMap["\(method.uppercased()):\(path)"],
              let entry = responses[override.statusCode]
        else {
            return try await next.respond(to: request)
        }

        var headers = HTTPHeaders()
        headers.contentType = .json
        return Response(
            status: HTTPResponseStatus(statusCode: UInt(override.statusCode)),
            headers: headers,
            body: .init(string: entry.body)
        )
    }
}
