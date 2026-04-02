import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// DemoApp root tabs. Tab bar styling uses `UITabBar.appearance()`, which applies **process-wide** for this app;
/// acceptable here because DemoApp is a small sample with a single `TabView`.
struct MainView: View {
    init() {
        #if canImport(UIKit) && !os(watchOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        let item = UITabBarItemAppearance()
        item.normal.iconColor = .secondaryLabel
        item.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        item.selected.iconColor = .tintColor
        item.selected.titleTextAttributes = [.foregroundColor: UIColor.tintColor]
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }

    var body: some View {
        TabView {
            OpenAPIExecuteView()
                .tabItem { Label("OpenAPI", systemImage: "arrow.left.arrow.right.circle") }
            HengeRootView()
                .tabItem { Label("Henge", systemImage: "slider.horizontal.3") }
        }
    }
}
