import Foundation
import HTTPTypes

/// HTTP route contract for the Henge admin API (`{pathPrefix}/__kawarimi/*`).
public enum KawarimiAdminRoute: Sendable, CaseIterable {
    case spec
    case status
    case configure
    case remove
    case reset
    case reload

    public var httpMethod: HTTPRequest.Method {
        switch self {
        case .spec, .status: .get
        case .configure, .remove, .reset, .reload: .post
        }
    }

    public var relativePath: String {
        switch self {
        case .spec: "spec"
        case .status: "status"
        case .configure: "configure"
        case .remove: "remove"
        case .reset: "reset"
        case .reload: "reload"
        }
    }

    public var successStatusCode: Int {
        switch self {
        case .reload: 204
        default: 200
        }
    }

    public init?(relativePath: String, httpMethod: HTTPRequest.Method) {
        guard let route = Self.allCases.first(where: {
            $0.relativePath == relativePath && $0.httpMethod == httpMethod
        }) else {
            return nil
        }
        self = route
    }

    /// Builds `{baseURL}/{managementSegment}/{route.relativePath}` using the same rules as ``KawarimiAPIClient``.
    public static func adminURL(baseURL: URL, route: KawarimiAdminRoute) -> URL {
        baseURL
            .appendingPathComponent(KawarimiAdminPath.managementSegment)
            .appendingPathComponent(route.relativePath)
    }
}
