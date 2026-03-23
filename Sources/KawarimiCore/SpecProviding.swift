import Foundation

public protocol SpecMetaProviding: Sendable {
    var title: String { get }
    var version: String { get }
    var description: String? { get }
    var serverURL: String { get }
    /// ストア・サーバのマウント path と一致させる。
    var apiPathPrefix: String { get }
}

public protocol SpecMockResponseProviding: Sendable {
    var statusCode: Int { get }
    var contentType: String { get }
    var body: String { get }
    var exampleId: String? { get }
    var summary: String? { get }
    var description: String? { get }
}

public protocol SpecEndpointProviding: Sendable {
    var path: String { get }
    var method: String { get }
    var operationId: String { get }
    var responseList: [any SpecMockResponseProviding] { get }
}
