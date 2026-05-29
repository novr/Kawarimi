import DemoSupport
import KawarimiCore
import KawarimiHenge
import SwiftUI

struct HengeRootView: View {
    var body: some View {
        if let url = KawarimiDemoClientURL.clientBaseURL {
            KawarimiConfigView(client: KawarimiAPIClient(baseURL: url))
        } else {
            ContentUnavailableView(
                "Invalid server URL",
                systemImage: "exclamationmark.triangle",
                description: Text("Set KAWARIMI_BASE_URL or use the default \(KawarimiDemoClientURL.defaultBaseURL).")
            )
        }
    }
}
