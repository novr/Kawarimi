import Foundation

/// Bounds for Proxy upstream forward (dev sidecar; not override JSON storage).
public enum KawarimiProxyForwardLimits {
    /// Maximum request body size (bytes) forwarded to upstream.
    public static let maxRequestBodyBytes = 10_485_760

    /// Maximum upstream response body size (bytes) returned through the Proxy.
    public static let maxResponseBodyBytes = 10_485_760
}
