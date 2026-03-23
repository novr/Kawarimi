import Foundation

/// OpenAPI の API マウントパス（`servers[0].url` の path、`KawarimiConfigStore.pathPrefix` 等）の正規化を一箇所に集約する。
public enum OpenAPIPathPrefix {
    /// 空白除去、末尾 `/`（ルート以外）除去、先頭 `/` 付与。中身が空なら `defaultIfEmpty` を同様に正規化して返す。
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

    /// OpenAPI `registerHandlers(..., serverURL:)` 向け。ランタイムは **path のみ**参照し、host はプレースホルダ。
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
