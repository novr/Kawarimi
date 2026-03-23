import Foundation

/// servers URL・ConfigStore などで同じプレフィックス規則にそろえるための集約。
public enum OpenAPIPathPrefix {
    /// `servers` やプレフィックス未指定時のフォールバック（空入力を正規化するときの既定マウント path）。
    public static let defaultMountPath = "/api"

    /// - Parameter defaultIfEmpty: `raw` が空のときの代替。省略時は `defaultMountPath`。
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

    /// `registerHandlers(..., serverURL:)` 向け。ランタイムは **path だけ**参照するので host は固定の無効ドメインでよい。
    public static func stubServerURL(pathPrefix: String) -> URL? {
        let path = normalizedPrefix(pathPrefix)
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
