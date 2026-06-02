#if os(macOS) || os(Linux)
import KawarimiCore
import Vapor

func adminSuccessHTTPStatus(for route: KawarimiAdminRoute) -> HTTPStatus {
    switch route.successStatusCode {
    case 200: .ok
    case 204: .noContent
    default: HTTPStatus(statusCode: route.successStatusCode)
    }
}
#endif
