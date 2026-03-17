import DemoAPI
import KawarimiHenge
import SwiftUI

/// DemoAppUI 用ルート。Package の HengeConfigView に serverURL と Spec 用クロージャを渡す。
struct DemoHengeRootView: View {
    @Binding var serverURL: String

    private var baseURL: URL {
        URL(string: serverURL) ?? URL(string: defaultServerURLString)!
    }

    private var client: HengeAPIClient {
        HengeAPIClient(baseURL: baseURL)
    }

    var body: some View {
        HengeConfigView(
            serverURL: $serverURL,
            specProvider: {
                let spec: SpecResponse = try await client.fetchSpec(as: SpecResponse.self)
                return (meta: spec.meta, endpoints: spec.endpoints)
            },
            fetchOverrides: { try await client.fetchOverrides() },
            configureOverride: { try await client.configure(override: $0) },
            resetAllOverrides: { try await client.reset() }
        )
    }
}
