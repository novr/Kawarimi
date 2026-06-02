import Foundation

/// HTTP header names for the Henge admin API (`{pathPrefix}/__kawarimi/*`).
public enum KawarimiAdminHeaders {
    /// Outcome of `POST …/__kawarimi/reload`: `applied` or `unchanged`.
    public static let reloadOutcome = "X-Kawarimi-Reload"

    /// JSON request/response bodies on admin routes (`POST …/configure`, `GET …/spec`, …).
    public static let jsonContentType = "application/json"
}

/// Result of ``KawarimiConfigStore/reloadFromDisk()`` and `POST …/__kawarimi/reload`.
public enum KawarimiConfigReloadResult: Sendable, Equatable {
    case applied
    case unchanged

    public var httpHeaderValue: String {
        switch self {
        case .applied: "applied"
        case .unchanged: "unchanged"
        }
    }

    public init?(httpHeaderValue: String) {
        switch httpHeaderValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "applied": self = .applied
        case "unchanged": self = .unchanged
        default: return nil
        }
    }
}
