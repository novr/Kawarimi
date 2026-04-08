import DemoAPI
import KawarimiCore
import KawarimiHenge
import SwiftUI

struct HengeRootView: View {
    private var client: KawarimiAPIClient {
        KawarimiAPIClient(baseURL: KawarimiExampleConfig.clientBaseURL!)
    }

    var body: some View {
        KawarimiConfigView(client: client, specType: SpecResponse.self)
    }
}
