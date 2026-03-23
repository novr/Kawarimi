import Foundation
import KawarimiCore

/// DemoServer は OpenAPI と `__kawarimi/*` の両方を `serverURL + apiPathPrefix` 配下にマウントする（例: `/api`, `/api/__kawarimi/spec`）。

enum ServerURLNormalization {
    /// OpenAPI `servers[0].url` から、`apiPathPrefix` と一致するパスを除いたオリジン（例 `https://example.com/api` → `https://example.com`）。パース失敗時は `http://localhost:8080`。
    static func defaultServerBaseURLString(openAPIServerURL: String, apiPathPrefix: String) -> String {
        let pref = OpenAPIPathPrefix.normalizedPrefix(apiPathPrefix, defaultIfEmpty: "/api")
        guard let u = URL(string: openAPIServerURL), u.scheme != nil, u.host != nil else {
            return "http://localhost:8080"
        }
        let docPath = OpenAPIPathPrefix.normalizedPrefix(u.path, defaultIfEmpty: "/")
        if docPath == pref {
            return originStringStrippingPath(of: u) ?? "http://localhost:8080"
        }
        return originStringStrippingPath(of: u) ?? "http://localhost:8080"
    }

    /// OpenAPI `Client` のベース URL（ホスト + `apiPathPrefix` セグメント）。`apiPathPrefix` が空なら `/api` 相当。
    static func openAPIClientBaseURL(serverBase: String, apiPathPrefix: String) -> URL? {
        let baseTrimmed = serverBase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: baseTrimmed), base.scheme != nil else { return nil }

        let prefix = OpenAPIPathPrefix.normalizedPrefix(apiPathPrefix, defaultIfEmpty: "/api")
        let segments = prefix.split(separator: "/").map(String.init)
        var url = base
        for seg in segments where !seg.isEmpty {
            url = url.appendingPathComponent(seg)
        }
        return url
    }

    /// ホストのみのベース URL（レガシー・テスト用）。Henge は `openAPIClientBaseURL` を使うこと。
    static func hengeBaseURL(from serverBase: String) -> URL? {
        let trimmed = serverBase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }

    private static func originStringStrippingPath(of url: URL) -> String? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil
        return components?.string
    }
}
