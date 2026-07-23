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

public protocol SpecSecuritySchemeProviding: Sendable {
    var name: String { get }
    var type: String { get }
    var description: String? { get }
    var apiKeyName: String? { get }
    var apiKeyIn: String? { get }
    var httpScheme: String? { get }
    var bearerFormat: String? { get }
    var openIdConnectURL: String? { get }
}

public protocol SpecScopedSecuritySchemeProviding: Sendable {
    var name: String { get }
    var scopes: [String]? { get }
}

public protocol SpecSecurityRequirementProviding: Sendable {
    var schemeList: [any SpecScopedSecuritySchemeProviding] { get }
}

public protocol SpecEndpointProviding: Identifiable, Sendable {
    var path: String { get }
    var method: HTTPRequest.Method { get }
    var operationId: String { get }
    /// OpenAPI operation `tags` when present; `nil` when the operation has no tags.
    var tags: [String]? { get }
    /// Effective OpenAPI `security` for this operation; `nil` when none applies.
    var security: [any SpecSecurityRequirementProviding]? { get }
    /// Merged path-item and operation parameters (path, query, header); `nil` when none.
    var parameters: [SpecParameter]? { get }
    /// OpenAPI `requestBody` rows for `application/json`; `nil` when absent or unsupported.
    var requestBodies: [SpecRequestBody]? { get }
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
    public var tags: [String]? { nil }
    public var security: [any SpecSecurityRequirementProviding]? { nil }
    public var parameters: [SpecParameter]? { nil }
    public var requestBodies: [SpecRequestBody]? { nil }
}
