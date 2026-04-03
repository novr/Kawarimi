import SwiftUI

/// Layout flags derived from size classes so behavior can be unit-tested without a View hierarchy.
enum NavigationLayoutLogic {
    /// Prefer stack navigation when either axis is compact (e.g. iPhone landscape reports regular width + compact height).
    static func useCompactNavigation(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) -> Bool {
        #if os(iOS)
        if horizontal == .compact { return true }
        if vertical == .compact { return true }
        return false
        #else
        horizontal == .compact
        #endif
    }

    /// Tighter chrome when vertical space is compact (e.g. iPhone landscape).
    static func explorerTightVertical(vertical: UserInterfaceSizeClass?) -> Bool {
        #if os(iOS)
        vertical == .compact
        #else
        false
        #endif
    }
}
