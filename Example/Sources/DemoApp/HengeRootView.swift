import DemoAPI
import KawarimiHenge
import SwiftUI

/// Example `DemoApp` 用ルート。`KawarimiConfigView` に serverURL と Spec 用クロージャを渡す。
struct HengeRootView: View {
    @Binding var serverBaseURL: String
    @Binding var apiPathPrefix: String

    /// OpenAPI と同じ API ベース（`pathPrefix` 込み）。`__kawarimi` はこの URL 直下にマウントされる。
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
