import Foundation

/// Decodable wire type for ``KawarimiAPIClient/fetchSpec(as:)`` when wiring **KawarimiHenge**.
///
/// Kawarimi code generation adds `extension SpecResponse: KawarimiFetchedSpec {}` on the generated `SpecResponse`.
public protocol KawarimiFetchedSpec: Decodable, Sendable {
    associatedtype FetchedSpecMeta: SpecMetaProviding
    associatedtype FetchedSpecEndpoint: SpecEndpointProviding
    var meta: FetchedSpecMeta { get }
    var endpoints: [FetchedSpecEndpoint] { get }
}
