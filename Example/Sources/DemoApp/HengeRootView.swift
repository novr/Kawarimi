import DemoAPI
import KawarimiHenge
import SwiftUI

struct HengeRootView: View {
    @Binding var serverBaseURL: String
    @Binding var apiPathPrefix: String

    /// Henge は OpenAPI クライアントと同じ base（`/api` 等）を使わないと `__kawarimi` に届かない。
    private var baseURL: URL {
        let m = KawarimiSpec.meta
        let fallbackBase = ServerURLNormalization.defaultServerBaseURLString(
            openAPIServerURL: m.serverURL,
            apiPathPrefix: m.apiPathPrefix
        )
        return ServerURLNormalization.openAPIClientBaseURL(serverBase: serverBaseURL, apiPathPrefix: apiPathPrefix)
            ?? ServerURLNormalization.openAPIClientBaseURL(
                serverBase: fallbackBase,
                apiPathPrefix: m.apiPathPrefix
            )!
    }

    private var client: KawarimiAPIClient {
        KawarimiAPIClient(baseURL: baseURL)
    }

    var body: some View {
        KawarimiConfigView(
            serverURL: $serverBaseURL,
            specProvider: {
                let spec: SpecResponse = try await client.fetchSpec(as: SpecResponse.self)
                return (meta: spec.meta, endpoints: spec.endpoints)
            },
            fetchOverrides: { try await client.fetchOverrides() },
            configureOverride: { try await client.configure(override: $0) },
            resetAllOverrides: { try await client.reset() },
            apiPathPrefixSync: $apiPathPrefix
        )
    }
}
