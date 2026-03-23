import DemoAPI
import Foundation
import SwiftUI

private enum KawarimiExampleDefaults {
    static let serverBaseURLKey = "kawarimi.example.serverBaseURL"
    static let apiPathPrefixKey = "kawarimi.example.apiPathPrefix"
}

struct MainView: View {
    @State private var serverBaseURL: String
    @State private var apiPathPrefix: String

    init() {
        let defaults = UserDefaults.standard
        let meta = KawarimiSpec.meta
        _serverBaseURL = State(
            initialValue: defaults.string(forKey: KawarimiExampleDefaults.serverBaseURLKey) ?? meta.serverURL
        )
        _apiPathPrefix = State(
            initialValue: defaults.string(forKey: KawarimiExampleDefaults.apiPathPrefixKey) ?? meta.apiPathPrefix
        )
    }

    var body: some View {
        TabView {
            OpenAPIExecuteView(serverBaseURL: $serverBaseURL, apiPathPrefix: $apiPathPrefix)
                .tabItem { Label("OpenAPI", systemImage: "arrow.left.arrow.right.circle") }
            HengeRootView(serverBaseURL: $serverBaseURL, apiPathPrefix: $apiPathPrefix)
                .tabItem { Label("Henge", systemImage: "slider.horizontal.3") }
        }
        .onChange(of: serverBaseURL) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: KawarimiExampleDefaults.serverBaseURLKey)
        }
        .onChange(of: apiPathPrefix) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: KawarimiExampleDefaults.apiPathPrefixKey)
        }
    }
}
