import Foundation
import KawarimiCore

/// Example は **Server URL** と **API prefix** を別フィールドで持つ。`meta` は入力が解決できないときのフォールバック（`servers.url` / `apiPathPrefix`）。
enum ServerURLNormalization {
    static func clientURL(
        serverBaseURL: String,
        apiPathPrefix: String,
        meta: some SpecMetaProviding
    ) -> URL? {
        resolve(origin: serverBaseURL, pathPrefix: apiPathPrefix)
            ?? resolve(origin: meta.serverURL, pathPrefix: meta.apiPathPrefix)
    }

    /// オリジンに path が無いときだけ正規化したマウント path を付ける。URL の path がそれと同じなら付けない（pathPrefix の二重付与を防ぐ）。
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
