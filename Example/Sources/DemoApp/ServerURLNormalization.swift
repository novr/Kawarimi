import Foundation
import KawarimiCore

/// OpenAPI と `__kawarimi` が同じ API プレフィックス配下にある前提で、入力欄（オリジン）とクライアント base を切り分ける。
enum ServerURLNormalization {
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

    private static func originStringStrippingPath(of url: URL) -> String? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil
        return components?.string
    }
}
