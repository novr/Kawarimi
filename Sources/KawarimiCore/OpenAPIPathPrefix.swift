import Foundation

/// servers URL・ConfigStore などで同じプレフィックス規則にそろえるための集約。
public enum OpenAPIPathPrefix {
    public static func normalizedPrefix(_ raw: String, defaultIfEmpty: String = "/api") -> String {
        let trimmed = coreNormalize(raw)
        if trimmed.isEmpty {
            let fallback = coreNormalize(defaultIfEmpty)
            if fallback.isEmpty {
                return "/api"
            }
            return fallback.hasPrefix("/") ? fallback : "/" + fallback
        }
        return trimmed
    }

    /// OpenAPI ランタイムは `serverURL` の path だけ使うため、host は意味のない固定値でよい。
    public static func serverURLForOpenAPIPathOnlyMount(pathPrefix raw: String) -> URL? {
        let path = normalizedPrefix(raw, defaultIfEmpty: "/api")
        var components = URLComponents()
        components.scheme = "https"
        components.host = "kawarimi.openapi.invalid"
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
}
