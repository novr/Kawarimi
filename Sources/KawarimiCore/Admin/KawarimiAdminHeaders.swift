import Foundation

/// HTTP header names for the Henge admin API (`{pathPrefix}/__kawarimi/*`).
public enum KawarimiAdminHeaders {
    /// Outcome of `POST …/__kawarimi/reload`: `applied` or `unchanged`.
    public static let reloadOutcome = "X-Kawarimi-Reload"

    /// JSON request/response bodies on admin routes (`POST …/configure`, `POST …/reload`, `GET …/spec`, …).
    public static let jsonContentType = "application/json"
}

/// Result of ``KawarimiConfigStore/reloadFromDisk()`` and the `X-Kawarimi-Reload` header on `POST …/__kawarimi/reload`.
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

/// Outcome of ``KawarimiAPIClient/reload()`` — reload header value plus the post-reload override list (`GET …/status` shape).
public struct KawarimiConfigReloadResponse: Sendable, Equatable {
    public var result: KawarimiConfigReloadResult
    public var overrides: [MockOverride]

    public init(result: KawarimiConfigReloadResult, overrides: [MockOverride]) {
        self.result = result
        self.overrides = overrides
    }
}
