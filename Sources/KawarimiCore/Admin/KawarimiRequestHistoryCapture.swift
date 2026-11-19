import Foundation
import HTTPTypes

/// Shared capture helpers for Spy request history (headers, query, body UTF-8 prefix).
public enum KawarimiRequestHistoryCapture {
    public static let maxBodyUTF8Bytes = 1_048_576

    private static let redactedHeaderNames: Set<String> = [
        "authorization",
        "proxy-authorization",
        "cookie",
        "set-cookie",
    ]

    /// Lowercases header names; last value wins for duplicates. Sensitive values become `"[redacted]"`.
    public static func normalizedHeaders(from fields: HTTPFields) -> [String: String] {
        var result: [String: String] = [:]
        for field in fields {
            let key = field.name.rawName.lowercased()
            if redactedHeaderNames.contains(key) {
                result[key] = "[redacted]"
            } else {
                result[key] = field.value
            }
        }
        return result
    }

    /// Percent-decoded query items from a raw request path that may include `?…`.
    /// Parsed by hand: `URLComponents.percentEncodedQuery` traps on malformed input such as `%zz`, which clients control.
    public static func queryItems(from rawPath: String?) -> [RecordedQueryItem] {
        guard let rawPath, let question = rawPath.firstIndex(of: "?") else { return [] }
        var query = rawPath[rawPath.index(after: question)...]
        if let hash = query.firstIndex(of: "#") {
            query = query[..<hash]
        }
        return query.split(separator: "&", omittingEmptySubsequences: true).map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return RecordedQueryItem(
                name: decodeQueryComponent(parts[0]),
                value: parts.count == 2 ? decodeQueryComponent(parts[1]) : nil
            )
        }
    }

    private static func decodeQueryComponent(_ raw: Substring) -> String {
        let text = String(raw)
        return text.removingPercentEncoding ?? text
    }

    /// Reads filter query values (`operationId` / `path` / `method`) from a raw admin request path.
    public static func requestFilters(from rawPath: String?) -> (
        operationId: String?,
        path: String?,
        method: String?
    ) {
        var operationId: String?
        var path: String?
        var method: String?
        for item in queryItems(from: rawPath) {
            switch item.name {
            case "operationId":
                operationId = item.value
            case "path":
                path = item.value
            case "method":
                method = item.value
            default:
                break
            }
        }
        return (operationId, path, method)
    }

    /// Truncates at a UTF-8 character boundary within `maxBytes`. Invalid UTF-8 or empty → `nil`.
    /// Backs off at most 3 bytes (max UTF-8 scalar width − 1) and decodes once, so binary bodies stay O(n).
    public static func utf8Prefix(from data: Data, maxBytes: Int = maxBodyUTF8Bytes) -> String? {
        guard !data.isEmpty, maxBytes > 0 else { return nil }
        let bytes = Data(data.prefix(maxBytes))
        var end = bytes.count
        if data.count > maxBytes {
            let base = data.startIndex
            var backoff = 0
            while backoff < 3, end > 0, data[base + end] & 0xC0 == 0x80 {
                end -= 1
                backoff += 1
            }
        }
        guard end > 0, let string = String(data: bytes.prefix(end), encoding: .utf8), !string.isEmpty else {
            return nil
        }
        return string
    }
}
