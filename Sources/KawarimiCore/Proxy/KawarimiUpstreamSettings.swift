import Foundation

public struct KawarimiUpstreamForwardingConfiguration: Sendable, Equatable {
    public let origin: URL
    public let strictOriginOnly: Bool
    public let proxyDebug: Bool
    /// Path on `KAWARIMI_UPSTREAM_URL` is re-applied at forward time; origin-only avoids double-prefix risk.
    public let nonOriginPathWarning: String?

    public init(
        origin: URL,
        strictOriginOnly: Bool = false,
        proxyDebug: Bool = false,
        nonOriginPathWarning: String? = nil
    ) {
        self.origin = origin
        self.strictOriginOnly = strictOriginOnly
        self.proxyDebug = proxyDebug
        self.nonOriginPathWarning = nonOriginPathWarning
    }
}

public struct KawarimiUpstreamSettings: Sendable, Equatable {
    public let forwarding: KawarimiUpstreamForwardingConfiguration?
    public let invalidURLWarning: String?

    public init(forwarding: KawarimiUpstreamForwardingConfiguration?, invalidURLWarning: String? = nil) {
        self.forwarding = forwarding
        self.invalidURLWarning = invalidURLWarning
    }

    public var isForwardingEnabled: Bool { forwarding != nil }

    public var strictOriginViolation: Bool {
        guard let forwarding else { return false }
        return forwarding.strictOriginOnly && forwarding.nonOriginPathWarning != nil
    }

    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> KawarimiUpstreamSettings {
        let strict = Self.isTruthy(environment["KAWARIMI_UPSTREAM_STRICT"])
        let proxyDebug = Self.isTruthy(environment["KAWARIMI_PROXY_DEBUG"])
        let raw = environment["KAWARIMI_UPSTREAM_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else {
            return KawarimiUpstreamSettings(forwarding: nil)
        }
        guard let parsed = parseUpstreamURL(raw) else {
            return KawarimiUpstreamSettings(
                forwarding: nil,
                invalidURLWarning:
                    "KAWARIMI_UPSTREAM_URL is set but could not be parsed as an origin URL (value: \(raw))"
            )
        }
        return KawarimiUpstreamSettings(
            forwarding: KawarimiUpstreamForwardingConfiguration(
                origin: parsed.origin,
                strictOriginOnly: strict,
                proxyDebug: proxyDebug,
                nonOriginPathWarning: parsed.pathWarning
            )
        )
    }

    public static func parseUpstreamURL(_ raw: String) -> (origin: URL, pathWarning: String?)? {
        guard let url = URL(string: raw), let scheme = url.scheme, !scheme.isEmpty,
            let host = url.host, !host.isEmpty
        else {
            return nil
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port

        let path = url.path
        let hadNonOriginPath = !path.isEmpty && path != "/"
        let warning: String? = hadNonOriginPath
            ? "KAWARIMI_UPSTREAM_URL should be origin only (got path \(path)); path is re-applied via KawarimiPath.aligned at forward time"
            : nil

        guard let origin = components.url else { return nil }
        return (origin, warning)
    }

    private static func isTruthy(_ raw: String?) -> Bool {
        guard let raw else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
