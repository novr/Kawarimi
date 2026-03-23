import Foundation

/// Protocol for spec meta. Generated KawarimiSpec.Meta conforms to this (via plugin-generated extension).
public protocol SpecMetaProviding: Sendable {
    var title: String { get }
    var version: String { get }
    var description: String? { get }
    var serverURL: String { get }
    /// OpenAPI の API マウントパス（例: `/api`）。`KawarimiConfigStore.pathPrefix` と揃える。
    var apiPathPrefix: String { get }
}

/// Protocol for a single mock response in an endpoint. Generated KawarimiSpec.MockResponse conforms to this.
public protocol SpecMockResponseProviding: Sendable {
    var statusCode: Int { get }
    var contentType: String { get }
    var body: String { get }
    var exampleId: String? { get }
    var summary: String? { get }
    var description: String? { get }
}

/// Protocol for spec endpoint. Generated KawarimiSpec.Endpoint conforms to this (via plugin-generated extension).
/// Use `responseList` to get responses as type-erased array; generated type exposes `responses: [MockResponse]` and implements `responseList` as that.
public protocol SpecEndpointProviding: Sendable {
    var path: String { get }
    var method: String { get }
    var operationId: String { get }
    var responseList: [any SpecMockResponseProviding] { get }
}
