import Foundation

public struct SpecRequestBody: Codable, Sendable {
    public var required: Bool
    public var description: String?
    public var contentType: String
    public var body: String
    public var exampleId: String?

    public init(
        required: Bool,
        contentType: String,
        body: String,
        exampleId: String? = nil,
        description: String? = nil
    ) {
        self.required = required
        self.contentType = contentType
        self.body = body
        self.exampleId = exampleId
        self.description = description
    }
}
