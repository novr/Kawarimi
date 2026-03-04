import Foundation

public struct MockOverride: Codable, Sendable {
    public var path: String
    public var method: String
    public var statusCode: Int
    public var exampleId: String?
    public var mockId: String?
    public var isEnabled: Bool

    public init(
        path: String,
        method: String,
        statusCode: Int,
        exampleId: String? = nil,
        mockId: String? = nil,
        isEnabled: Bool = true
    ) {
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.exampleId = exampleId
        self.mockId = mockId
        self.isEnabled = isEnabled
    }
}

public struct MockConfig: Codable, Sendable {
    public var overrides: [MockOverride]

    public init(overrides: [MockOverride] = []) {
        self.overrides = overrides
    }
}
