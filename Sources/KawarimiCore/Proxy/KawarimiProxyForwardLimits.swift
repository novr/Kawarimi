import Foundation

/// Dev-sidecar bounds; not read from override JSON.
public enum KawarimiProxyForwardLimits {
    /// Maximum request body size (bytes) forwarded to upstream.
    public static let maxRequestBodyBytes = 10_485_760

    /// Maximum upstream response body size (bytes) returned through the Proxy.
    public static let maxResponseBodyBytes = 10_485_760
}
