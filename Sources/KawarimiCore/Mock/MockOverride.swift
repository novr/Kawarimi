import Foundation
import HTTPTypes

public struct MockOverride: Codable, Sendable, Equatable {
    public var name: String?
    public var path: String
    public var method: HTTPRequest.Method
    public var statusCode: Int
    public var exampleId: String?
    public var isEnabled: Bool
    /// Non-empty overrides the spec example; empty string clears back to the spec default.
    public var body: String?
    /// When body is set and this is nil, the server treats the body as JSON.
    public var contentType: String?

    public var hasEffectiveCustomBody: Bool { body.map { !$0.isEmpty } ?? false }

    /// Upper bound (UTF-8 bytes) so config files and HTTP payloads stay bounded.
    public static let maxBodyLength = 1_000_000

    public init(
        name: String? = nil,
        path: String,
        method: HTTPRequest.Method,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil
    ) {
        self.name = name
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.exampleId = exampleId
        self.isEnabled = isEnabled
        self.body = body
        self.contentType = contentType
    }

    public init(
        name: String? = nil,
        path: String,
        method methodString: String,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil
    ) {
        let normalized = methodString.uppercased()
        guard let m = HTTPRequest.Method(normalized) else {
            preconditionFailure("Invalid HTTP method for MockOverride: \(methodString)")
        }
        self.init(
            name: name,
            path: path,
            method: m,
            statusCode: statusCode,
            exampleId: exampleId,
            isEnabled: isEnabled,
            body: body,
            contentType: contentType
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
    /// Deterministic ordering; first match wins when several overrides qualify.
    public static func sortedForInterceptorTieBreak(_ hits: [MockOverride]) -> [MockOverride] {
        hits.sorted { interceptorTieBreakKey($0) < interceptorTieBreakKey($1) }
    }

    private static func interceptorTieBreakKey(_ o: MockOverride)
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
