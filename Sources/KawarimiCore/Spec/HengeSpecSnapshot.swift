import Foundation
import HTTPTypes

/// Decodable wire shape for `GET …/__kawarimi/spec` when Henge does not link a host-generated `SpecResponse`.
public struct HengeSpecSnapshot: Codable, Sendable, KawarimiFetchedSpec {
    public struct Meta: Codable, Sendable, SpecMetaProviding {
        public var title: String
        public var version: String
        public var description: String?
        public var serverURL: String
        public var apiPathPrefix: String
    }

    public struct SecurityScheme: Codable, Sendable, SpecSecuritySchemeProviding {
        public var name: String
        public var type: String
        public var description: String?
        public var apiKeyName: String?
        public var apiKeyIn: String?
        public var httpScheme: String?
        public var bearerFormat: String?
        public var openIdConnectURL: String?
    }

    public struct ScopedSecurityScheme: Codable, Sendable, SpecScopedSecuritySchemeProviding {
        public var name: String
        public var scopes: [String]?
    }

    public struct SecurityRequirement: Codable, Sendable, SpecSecurityRequirementProviding {
        public var schemes: [ScopedSecurityScheme]

        public var schemeList: [any SpecScopedSecuritySchemeProviding] { schemes }
    }

    public struct MockResponse: Codable, Sendable, SpecMockResponseProviding {
        public var statusCode: Int
        public var contentType: String
        public var body: String
        public var exampleId: String?
        public var summary: String?
        public var description: String?
    }

    public struct Endpoint: Codable, Sendable, SpecEndpointProviding {
        public var path: String
        public var method: HTTPRequest.Method
        public var operationId: String
        public var tags: [String]?
        public var security: [SecurityRequirement]?
        public var parameters: [SpecParameter]?
        public var responses: [MockResponse]

        public var responseList: [any SpecMockResponseProviding] { responses }
    }

    public var meta: Meta
    public var endpoints: [Endpoint]
    public var securitySchemes: [SecurityScheme]?

    public typealias FetchedSpecMeta = Meta
    public typealias FetchedSpecEndpoint = Endpoint

    public var securitySchemeCatalog: [any SpecSecuritySchemeProviding]? {
        guard let securitySchemes else { return nil }
        return securitySchemes.map { $0 as any SpecSecuritySchemeProviding }
    }
}
