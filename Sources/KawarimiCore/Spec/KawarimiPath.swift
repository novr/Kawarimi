import Foundation

/// OpenAPI-style path segments and alignment with a configurable API prefix (persisted `kawarimi.json` paths).
public enum KawarimiPath {
    public static func splitPathSegments(_ raw: String) -> [String] {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    public static func joinPathPrefix(_ segments: [String]) -> String {
        if segments.isEmpty { return "" }
        return "/" + segments.joined(separator: "/")
    }

    public static func aligned(path: String, pathPrefix: String) -> String {
        let prefix = joinPathPrefix(splitPathSegments(pathPrefix))
        var result = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !result.hasPrefix("/") {
            result = "/" + result
        }
        if !result.hasPrefix(prefix) {
            result = prefix + (result == "/" ? "" : result)
        }
        return (result as NSString).standardizingPath // resolve . / .. so paths match persisted JSON
    }
}
