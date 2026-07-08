#if os(macOS) || os(Linux)
import Foundation
import HTTPTypes
import KawarimiCore
import KawarimiServer
import Vapor

struct KawarimiAdminVaporMiddleware: AsyncMiddleware {
    let handler: KawarimiAdminHTTPHandler

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let httpRequest = HTTPRequest(
            method: HTTPRequest.Method(request.method.rawValue) ?? .get,
            scheme: request.url.scheme ?? "http",
            authority: request.headers.first(name: .host) ?? request.url.host ?? "localhost",
            path: KawarimiRequestPath.pathOnly(request.url.path)
        )
        let collected = try await request.body.collect(max: 10 * 1024 * 1024).get()
        let bodyData: Data?
        if let collected, collected.readableBytes > 0 {
            bodyData = Data(buffer: collected)
        } else {
            bodyData = nil
        }

        if let (httpResponse, responseBody) = try await handler.handle(request: httpRequest, body: bodyData) {
            var headers = HTTPHeaders()
            for field in httpResponse.headerFields {
                headers.replaceOrAdd(name: field.name.rawName, value: field.value)
            }
            let status = HTTPStatus(statusCode: httpResponse.status.code)
            if let responseBody {
                return Response(status: status, headers: headers, body: .init(data: responseBody))
            }
            return Response(status: status, headers: headers)
        }
        return try await next.respond(to: request)
    }
}
#endif
