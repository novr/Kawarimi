import Foundation
import HTTPTypes

public protocol SpecMetaProviding: Sendable {
    var title: String { get }
    var version: String { get }
    var description: String? { get }
    var serverURL: String { get }
    var apiPathPrefix: String { get }
}

public protocol SpecMockResponseProviding: Identifiable, Sendable {
    var statusCode: Int { get }
    var contentType: String { get }
    var body: String { get }
    var exampleId: String? { get }
    var summary: String? { get }
    var description: String? { get }
}

public protocol SpecEndpointProviding: Identifiable, Sendable {
    var path: String { get }
    var method: HTTPRequest.Method { get }
    var operationId: String { get }
    var responseList: [any SpecMockResponseProviding] { get }
}

extension SpecMockResponseProviding {
    /// Stable across multiple examples for the same HTTP status (distinct `exampleId`).
    public var id: String {
        let trimmed = exampleId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return "\(statusCode)#\(KawarimiExampleIds.defaultResponseMapKey)"
        }
        return "\(statusCode)#\(trimmed)"
    }
}

extension SpecEndpointProviding {
    public var id: String { operationId }
}
