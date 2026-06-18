import Foundation
import HTTPTypes

public struct MockOverride: Codable, Sendable, Equatable {
    /// Thrown by APIs that build a ``MockOverride`` from a raw method string when parsing fails.
    public struct InvalidMethodStringError: Error, Sendable, LocalizedError {
        public var rawMethod: String
        public init(rawMethod: String) { self.rawMethod = rawMethod }

        public var errorDescription: String? {
            "Invalid HTTP method string: \(rawMethod)"
        }
    }

    public var name: String?
    /// Optional stable row identifier for update/remove identity during staged migration.
    public var rowId: String?
    public var path: String
    public var method: HTTPRequest.Method
    public var statusCode: Int
    public var exampleId: String?
    public var isEnabled: Bool
    /// Non-empty overrides the spec example; empty string clears back to the spec default.
    public var body: String?
    /// When body is set and this is nil, the server treats the body as JSON.
    public var contentType: String?
    /// Optional response delay in milliseconds before the mock body is returned.
    public var delayMs: Int?

    public var hasEffectiveCustomBody: Bool { body.map { !$0.isEmpty } ?? false }

    /// Upper bound (UTF-8 bytes) so config files and HTTP payloads stay bounded.
    public static let maxBodyLength = 1_000_000

    public init(
        name: String? = nil,
        rowId: String? = nil,
        path: String,
        method: HTTPRequest.Method,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil,
        delayMs: Int? = nil
    ) {
        self.name = name
        self.rowId = rowId
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.exampleId = exampleId
        self.isEnabled = isEnabled
        self.body = body
        self.contentType = contentType
        self.delayMs = delayMs
    }

    /// Returns `nil` when `methodString` is not a valid HTTP method for ``HTTPRequest/Method``.
    public init?(
        name: String? = nil,
        rowId: String? = nil,
        path: String,
        method methodString: String,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil,
        delayMs: Int? = nil
    ) {
        let normalized = methodString.uppercased()
        guard let m = HTTPRequest.Method(normalized) else { return nil }
        self.init(
            name: name,
            rowId: rowId,
            path: path,
            method: m,
            statusCode: statusCode,
            exampleId: exampleId,
            isEnabled: isEnabled,
            body: body,
            contentType: contentType,
            delayMs: delayMs
        )
    }
}

public struct KawarimiConfig: Codable, Sendable {
    public var overrides: [MockOverride]

    public init(overrides: [MockOverride] = []) {
        self.overrides = overrides
    }

    enum CodingKeys: String, CodingKey {
        case overrides
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.overrides = try container.decodeIfPresent([MockOverride].self, forKey: .overrides) ?? []
    }
}

extension MockOverride {
    public static func normalizedRowId(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        guard UUID(uuidString: trimmed) != nil else { return nil }
        return trimmed.lowercased()
    }

    /// Deterministic ordering; first match wins when several overrides qualify.
    public static func sortedForOverrideTieBreak(_ hits: [MockOverride]) -> [MockOverride] {
        hits.sorted { overrideTieBreakKey($0) < overrideTieBreakKey($1) }
    }

    /// Backward-compatible name for ``sortedForOverrideTieBreak(_:)``.
    public static func sortedForInterceptorTieBreak(_ hits: [MockOverride]) -> [MockOverride] {
        sortedForOverrideTieBreak(hits)
    }

    private static func overrideTieBreakKey(_ o: MockOverride)
        -> (String, Int, String, String)
    {
        (
            o.path,
            o.statusCode,
            o.name ?? "",
            o.exampleId ?? ""
        )
    }
}
