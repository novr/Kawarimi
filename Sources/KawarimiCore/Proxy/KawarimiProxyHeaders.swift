import Foundation
import HTTPTypes

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

    /// When ``omitContentLength`` is `true`, drops `Content-Length` so the outbound transport can set it from the forwarded body.
    public static func forwardingRequestHeaders(
        from source: HTTPFields,
        omitContentLength: Bool = false
    ) -> HTTPFields {
        let dynamicHopByHop = dynamicHopByHopNames(from: source)
        var result = HTTPFields()
        for field in source {
            let lower = field.name.rawName.lowercased()
            if isHopByHopHeader(name: lower) { continue }
            if isKawarimiControlHeader(name: lower) { continue }
            if omitContentLength, lower == "content-length" { continue }
            if dynamicHopByHop.contains(lower) { continue }
            result.append(field)
        }
        return result
    }

    public static func forwardingResponseHeaders(from source: HTTPFields) -> HTTPFields {
        let dynamicHopByHop = dynamicHopByHopNames(from: source)
        var result = HTTPFields()
        for field in source {
            let lower = field.name.rawName.lowercased()
            if isHopByHopHeader(name: lower) { continue }
            if isKawarimiControlHeader(name: lower) { continue }
            if dynamicHopByHop.contains(lower) { continue }
            result.append(field)
        }
        return result
    }

    /// Parses the `Connection` header to extract dynamically declared hop-by-hop field names (RFC 7230 §6.1).
    private static func dynamicHopByHopNames(from fields: HTTPFields) -> Set<String> {
        guard let connectionName = HTTPField.Name("Connection"),
              let value = fields[connectionName]
        else { return [] }
        return Set(
            value.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
}
