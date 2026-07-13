import Foundation
import HTTPTypes

/// Header names and strip rules for Kawarimi Proxy (`ServerMiddleware` upstream forward).
public enum KawarimiProxyHeaders {
    public static let proxyAction = "X-Kawarimi-Proxy-Action"
    public static let actionMock = "mock"
    public static let actionForward = "forward"

    private static let hopByHopNames: Set<String> = [
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailer",
        "transfer-encoding",
        "upgrade",
        "host",
    ]

    public static func isHopByHopHeader(name: String) -> Bool {
        hopByHopNames.contains(name.lowercased())
    }

    public static func isKawarimiControlHeader(name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("x-kawarimi-") || lower.hasPrefix("x-next-kawarimi-")
    }

    /// Request headers to send upstream: drops hop-by-hop and Kawarimi control fields.
    ///
    /// When ``omitContentLength`` is `true`, drops `Content-Length` so the outbound transport can set it from the forwarded body.
    public static func forwardingRequestHeaders(
        from source: HTTPFields,
        omitContentLength: Bool = false
    ) -> HTTPFields {
        var result = HTTPFields()
        for field in source {
            let lower = field.name.rawName.lowercased()
            if isHopByHopHeader(name: lower) { continue }
            if isKawarimiControlHeader(name: lower) { continue }
            if omitContentLength, lower == "content-length" { continue }
            result.append(field)
        }
        return result
    }

    /// Response headers returned to the Proxy client: drops hop-by-hop and Kawarimi control fields from upstream.
    public static func forwardingResponseHeaders(from source: HTTPFields) -> HTTPFields {
        var result = HTTPFields()
        for field in source {
            let lower = field.name.rawName.lowercased()
            if isHopByHopHeader(name: lower) { continue }
            if isKawarimiControlHeader(name: lower) { continue }
            result.append(field)
        }
        return result
    }
}
