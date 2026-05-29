import DemoSupport
import KawarimiCore
import KawarimiHenge
import SwiftUI

struct HengeRootView: View {
    private var client: KawarimiAPIClient {
        KawarimiAPIClient(baseURL: KawarimiDemoClientURL.clientBaseURL!)
    }

    var body: some View {
        KawarimiConfigView(client: client)
    }
}
