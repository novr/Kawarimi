import DemoAPI
import KawarimiCore
import KawarimiHenge
import SwiftUI

struct HengeRootView: View {
    /// Must match the OpenAPI client base URL or requests will not reach `__kawarimi`.
    private var baseURL: URL {
        KawarimiExampleConfig.clientBaseURL!
    }

    private var client: KawarimiAPIClient {
        KawarimiAPIClient(baseURL: baseURL)
    }

    var body: some View {
        KawarimiConfigView(
            serverURL: KawarimiExampleConfig.serverBaseURL,
            specProvider: {
                let spec: SpecResponse = try await client.fetchSpec(as: SpecResponse.self)
                return (meta: spec.meta, endpoints: spec.endpoints)
            },
            fetchOverrides: { try await client.fetchOverrides() },
            configureOverride: { try await client.configure(override: $0) },
            removeOverride: { try await client.removeOverride(override: $0) },
            resetAllOverrides: { try await client.reset() }
        )
    }
}
