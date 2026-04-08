import Foundation

@available(*, deprecated, message: "Use KawarimiPath.splitPathSegments, joinPathPrefix, aligned(path:pathPrefix:), and URLComponents instead.")
public enum OpenAPIPathPrefix {
    public static let defaultMountPath = "/api"

    public static func normalizedPrefix(_ raw: String, defaultIfEmpty: String? = nil) -> String {
        let whenEmpty = defaultIfEmpty ?? defaultMountPath
        let trimmed = coreNormalize(raw)
        if trimmed.isEmpty {
            let fallback = coreNormalize(whenEmpty)
            if fallback.isEmpty {
                return defaultMountPath
            }
            return fallback.hasPrefix("/") ? fallback : "/" + fallback
        }
        return trimmed
    }

    public static func stubServerURL(pathPrefix: String) -> URL? {
        let path = normalizedPrefix(pathPrefix)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "kawarimi.openapi.invalid" // swift-openapi matches by path; host is arbitrary
        components.path = path
        return components.url
    }

    private static func coreNormalize(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("/"), t.count > 1 {
            t.removeLast()
        }
        if t.isEmpty {
            return ""
        }
        return t.hasPrefix("/") ? t : "/" + t
    }

    public static func configStoredPath(path: String, pathPrefix: String) -> String {
        KawarimiPath.aligned(path: path, pathPrefix: pathPrefix)
    }
}
