import DemoAPI
import KawarimiCore
import KawarimiHenge
import SwiftUI

struct HengeRootView: View {
    /// Must match the OpenAPI client base URL or requests will not reach `__kawarimi`.
    private var client: KawarimiAPIClient {
        KawarimiAPIClient(baseURL: KawarimiExampleConfig.clientBaseURL!)
    }

    var body: some View {
        KawarimiConfigView(client: client, specType: SpecResponse.self)
    }
}
