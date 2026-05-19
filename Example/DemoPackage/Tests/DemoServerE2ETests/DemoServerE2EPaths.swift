#if os(macOS)
import DemoAPI
import Foundation
import KawarimiCore

enum DemoServerE2EPaths {
    static let apiPrefix = KawarimiSpec.meta.apiPathPrefix

    static var greetPath: String {
        KawarimiPath.aligned(path: "/greet", pathPrefix: apiPrefix)
    }

    static func apiBaseURL(origin: URL) -> URL {
        var url = origin
        for segment in KawarimiPath.splitPathSegments(apiPrefix) {
            url = url.appending(path: segment)
        }
        return url
    }
}
#endif
