import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            OpenAPIExecuteView()
                .tabItem { Label("OpenAPI", systemImage: "arrow.left.arrow.right.circle") }
            HengeRootView()
                .tabItem { Label("Henge", systemImage: "slider.horizontal.3") }
        }
    }
}
