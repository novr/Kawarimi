import Foundation

public struct MockOverride: Codable, Sendable {
    /// Optional display name when specifying an override by path (e.g. operationId or custom label).
    public var name: String?
    public var path: String
    public var method: String
    public var statusCode: Int
    public var exampleId: String?
    public var mockId: String?
    public var isEnabled: Bool
    /// Override response body. When non-nil and non-empty, middleware returns this instead of spec's responseMap.
    /// Empty string is treated as "no override" and falls back to spec.
    public var body: String?
    /// Override Content-Type. When nil and body is set (non-empty), middleware uses "application/json".
    public var contentType: String?

    /// True when custom body should be used (non-nil and non-empty). Empty string falls back to spec.
    public var hasEffectiveCustomBody: Bool { body.map { !$0.isEmpty } ?? false }

    public init(
        name: String? = nil,
        path: String,
        method: String,
        statusCode: Int,
        exampleId: String? = nil,
        mockId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil
    ) {
        self.name = name
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.exampleId = exampleId
        self.mockId = mockId
        self.isEnabled = isEnabled
        self.body = body
        self.contentType = contentType
    }
}

public struct KawarimiConfig: Codable, Sendable {
    public var overrides: [MockOverride]

    public init(overrides: [MockOverride] = []) {
        self.overrides = overrides
    }
}
