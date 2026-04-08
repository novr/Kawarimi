import DemoAPI
import Foundation
import KawarimiCore

enum KawarimiExampleConfig {
    static var serverBaseURL: String { KawarimiSpec.meta.serverURL }
    static var apiPathPrefix: String { KawarimiSpec.meta.apiPathPrefix }

    static var clientBaseURL: URL? {
        resolve(origin: serverBaseURL, pathPrefix: apiPathPrefix)
    }

    private static func resolve(origin: String, pathPrefix: String) -> URL? {
        let trimmed = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var c = URLComponents(string: trimmed),
              let scheme = c.scheme, !scheme.isEmpty else { return nil }

        let prefixSegs = KawarimiPath.splitPathSegments(pathPrefix)
        let serverSegs = KawarimiPath.splitPathSegments(c.path)

        if serverSegs == prefixSegs {
            return c.url
        }

        if serverSegs.isEmpty {
            c.path = KawarimiPath.joinPathPrefix(prefixSegs)
            return c.url
        }

        c.path = KawarimiPath.joinPathPrefix(prefixSegs)
        c.query = nil
        c.fragment = nil
        return c.url
    }
}
