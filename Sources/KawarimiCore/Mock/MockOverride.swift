import Foundation
import HTTPTypes

public struct MockOverrideRowID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: trimmed) else { return nil }
        self.rawValue = uuid.uuidString.lowercased()
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let id = Self(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid MockOverrideRowID UUID string")
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func generate() -> Self {
        Self(rawValue: UUID().uuidString)!
    }
}

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
    public var rowId: MockOverrideRowID?
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
    /// Optional failure simulation; takes precedence over ``delayMs`` when set.
    public var failureMode: MockFailureMode?

    public var hasEffectiveCustomBody: Bool { body.map { !$0.isEmpty } ?? false }

    /// Upper bound (UTF-8 bytes) so config files and HTTP payloads stay bounded.
    public static let maxBodyLength = 1_000_000

    public init(
        name: String? = nil,
        rowId: MockOverrideRowID? = nil,
        path: String,
        method: HTTPRequest.Method,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil,
        delayMs: Int? = nil,
        failureMode: MockFailureMode? = nil
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
        self.failureMode = failureMode
    }

    /// Returns `nil` when `methodString` is not a valid HTTP method for ``HTTPRequest/Method``.
    public init?(
        name: String? = nil,
        rowId: MockOverrideRowID? = nil,
        path: String,
        method methodString: String,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil,
        delayMs: Int? = nil,
        failureMode: MockFailureMode? = nil
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
            delayMs: delayMs,
            failureMode: failureMode
        )
    }

    enum CodingKeys: String, CodingKey {
        case name
        case rowId
        case path
        case method
        case statusCode
        case exampleId
        case isEnabled
        case body
        case contentType
        case delayMs
        case failureMode
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        if let rawRowId = try container.decodeIfPresent(String.self, forKey: .rowId) {
            // Staged rollout: tolerate malformed rowId and treat it as absent.
            self.rowId = MockOverrideRowID(rawValue: rawRowId)
        } else {
            self.rowId = nil
        }
        self.path = try container.decode(String.self, forKey: .path)
        self.method = try container.decode(HTTPRequest.Method.self, forKey: .method)
        self.statusCode = try container.decode(Int.self, forKey: .statusCode)
        self.exampleId = try container.decodeIfPresent(String.self, forKey: .exampleId)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.body = try container.decodeIfPresent(String.self, forKey: .body)
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        self.delayMs = try container.decodeIfPresent(Int.self, forKey: .delayMs)
        self.failureMode = try container.decodeIfPresent(MockFailureMode.self, forKey: .failureMode)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(rowId?.rawValue, forKey: .rowId)
        try container.encode(path, forKey: .path)
        try container.encode(method, forKey: .method)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encodeIfPresent(exampleId, forKey: .exampleId)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(contentType, forKey: .contentType)
        try container.encodeIfPresent(delayMs, forKey: .delayMs)
        try container.encodeIfPresent(failureMode, forKey: .failureMode)
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
