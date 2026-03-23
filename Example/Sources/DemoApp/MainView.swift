import DemoAPI
import Foundation
import SwiftUI

private enum KawarimiExampleDefaults {
    static let serverBaseURLKey = "kawarimi.example.serverBaseURL"
    static let apiPathPrefixKey = "kawarimi.example.apiPathPrefix"
}

struct MainView: View {
    @State private var serverBaseURLString: String
    @State private var apiPathPrefixString: String

    init() {
        let defaults = UserDefaults.standard
        let meta = KawarimiSpec.meta
        let defaultBase = ServerURLNormalization.defaultServerBaseURLString(
            openAPIServerURL: meta.serverURL,
            apiPathPrefix: meta.apiPathPrefix
        )
        _serverBaseURLString = State(
            initialValue: defaults.string(forKey: KawarimiExampleDefaults.serverBaseURLKey) ?? defaultBase
        )
        _apiPathPrefixString = State(
            initialValue: defaults.string(forKey: KawarimiExampleDefaults.apiPathPrefixKey) ?? meta.apiPathPrefix
        )
    }

    var body: some View {
        TabView {
            OpenAPIExecuteView(serverBaseURL: $serverBaseURLString, apiPathPrefix: $apiPathPrefixString)
                .tabItem { Label("OpenAPI", systemImage: "arrow.left.arrow.right.circle") }
            HengeRootView(serverBaseURL: $serverBaseURLString, apiPathPrefix: $apiPathPrefixString)
                .tabItem { Label("Henge", systemImage: "slider.horizontal.3") }
        }
        .onChange(of: serverBaseURLString) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: KawarimiExampleDefaults.serverBaseURLKey)
        }
        .onChange(of: apiPathPrefixString) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: KawarimiExampleDefaults.apiPathPrefixKey)
        }
    }
}
