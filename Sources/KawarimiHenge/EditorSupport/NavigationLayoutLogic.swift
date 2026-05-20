import KawarimiHengeCore
import SwiftUI

/// Layout flags derived from size classes so behavior can be unit-tested without a View hierarchy.
enum NavigationLayoutLogic {
    static func useCompactNavigation(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) -> Bool {
        NavigationLayoutCore.useCompactNavigation(
            horizontalIsCompact: horizontal == .compact,
            verticalIsCompact: vertical == .compact,
            platformIsIOS: platformIsIOS
        )
    }

    static func explorerTightVertical(vertical: UserInterfaceSizeClass?) -> Bool {
        NavigationLayoutCore.explorerTightVertical(
            verticalIsCompact: vertical == .compact,
            platformIsIOS: platformIsIOS
        )
    }

    private static var platformIsIOS: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}
