import SwiftUI

/// 両タブで共有する Server URL の初期値（重複定義を避ける）
let defaultServerURLString = "http://localhost:8080"

/// メイン画面: OpenAPI の実行（fetch）と HengeConfigView の2機能。Server URL は1つで両タブ共有。
struct MainView: View {
    @State private var serverURLString = defaultServerURLString

    var body: some View {
        TabView {
            OpenAPIFetchView(serverURL: $serverURLString)
                .tabItem { Label("OpenAPI", systemImage: "arrow.down.circle") }
            DemoHengeRootView(serverURL: $serverURLString)
                .tabItem { Label("Henge", systemImage: "slider.horizontal.3") }
        }
    }
}
