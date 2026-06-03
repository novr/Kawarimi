#if os(macOS) || os(Linux)
import Foundation
import KawarimiCore
import Vapor

func adminSuccessHTTPStatus(for route: KawarimiAdminRoute) -> HTTPStatus {
    switch route.successStatusCode {
    case 200: .ok
    case 204: .noContent
    default: HTTPStatus(statusCode: route.successStatusCode)
    }
}

func adminOverridesJSONResponse(
    overrides: [MockOverride],
    route: KawarimiAdminRoute,
    extraHeaders: HTTPHeaders = HTTPHeaders()
) throws -> Response {
    let data = try JSONEncoder().encode(overrides)
    var headers = extraHeaders
    headers.contentType = .json
    return Response(
        status: adminSuccessHTTPStatus(for: route),
        headers: headers,
        body: .init(data: data)
    )
}
#endif
