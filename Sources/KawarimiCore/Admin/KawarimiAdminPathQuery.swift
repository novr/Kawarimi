import Foundation

/// Joins a path-only string with an optional raw query (no leading `?`).
public enum KawarimiAdminPathQuery {
    public static func pathWithQuery(_ pathOnly: String, query: String?) -> String {
        guard let query, !query.isEmpty else { return pathOnly }
        return pathOnly + "?" + query
    }
}
