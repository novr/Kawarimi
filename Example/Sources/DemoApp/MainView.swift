import DemoAPI
import Foundation
import SwiftUI

private enum KawarimiExampleDefaults {
    static let serverBaseURLKey = "kawarimi.example.serverBaseURL"
    static let apiPathPrefixKey = "kawarimi.example.apiPathPrefix"
}

struct MainView: View {
    @AppStorage(KawarimiExampleDefaults.serverBaseURLKey) private var serverBaseURL: String = ""
    @AppStorage(KawarimiExampleDefaults.apiPathPrefixKey) private var apiPathPrefix: String = ""

    var body: some View {
        TabView {
            OpenAPIExecuteView(serverBaseURL: $serverBaseURL, apiPathPrefix: $apiPathPrefix)
                .tabItem { Label("OpenAPI", systemImage: "arrow.left.arrow.right.circle") }
            HengeRootView(serverBaseURL: $serverBaseURL, apiPathPrefix: $apiPathPrefix)
                .tabItem { Label("Henge", systemImage: "slider.horizontal.3") }
        }
    }
}
