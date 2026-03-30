import DemoAPI
import Foundation
import KawarimiCore

/// Demo wiring: keep OpenAPI `servers` / `x-kawarimi` aligned with the demo server.
enum KawarimiExampleConfig {
    static var serverBaseURL: String { KawarimiSpec.meta.serverURL }
    static var apiPathPrefix: String { KawarimiSpec.meta.apiPathPrefix }

    /// Client base URL: origin plus `apiPathPrefix` (avoids double-appending paths).
    static var clientBaseURL: URL? {
        resolve(origin: serverBaseURL, pathPrefix: apiPathPrefix)
    }

    private static func resolve(origin: String, pathPrefix: String) -> URL? {
        let trimmed = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }

        let normalized = OpenAPIPathPrefix.normalizedPrefix(pathPrefix)
        var urlPath = url.path
        if urlPath.isEmpty { urlPath = "/" }
        urlPath = OpenAPIPathPrefix.normalizedPrefix(urlPath, defaultIfEmpty: "/")

        if urlPath == normalized {
            return url
        }
        if urlPath == "/" {
            var u = url
            for seg in normalized.split(separator: "/").map(String.init) where !seg.isEmpty {
                u = u.appendingPathComponent(seg)
            }
            return u
        }
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        c.path = ""
        c.query = nil
        c.fragment = nil
        guard let originOnly = c.url else { return nil }
        var u = originOnly
        for seg in normalized.split(separator: "/").map(String.init) where !seg.isEmpty {
            u = u.appendingPathComponent(seg)
        }
        return u
    }
}
