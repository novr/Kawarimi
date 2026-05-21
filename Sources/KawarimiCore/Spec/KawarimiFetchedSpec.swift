import Foundation

/// Expected decodable shape for the Kawarimi spec wire JSON when wiring **KawarimiHenge** via ``KawarimiAPIClient`` (see its `fetchSpec` overload constrained to this protocol).
///
/// Kawarimi code generation adds `extension SpecResponse: KawarimiFetchedSpec {}` on the generated `SpecResponse`.
public protocol KawarimiFetchedSpec: Decodable, Sendable {
    associatedtype FetchedSpecMeta: SpecMetaProviding
    associatedtype FetchedSpecEndpoint: SpecEndpointProviding
    var meta: FetchedSpecMeta { get }
    var endpoints: [FetchedSpecEndpoint] { get }
    /// OpenAPI `components.securitySchemes` when the wire document includes them (`SpecResponse.securitySchemes`).
    var securitySchemeCatalog: [any SpecSecuritySchemeProviding]? { get }
}

extension KawarimiFetchedSpec {
    public var securitySchemeCatalog: [any SpecSecuritySchemeProviding]? { nil }
}
