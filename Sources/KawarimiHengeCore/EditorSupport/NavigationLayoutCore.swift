/// Layout flags without SwiftUI size classes (unit-tested on Linux CI).
package enum NavigationLayoutCore {
    /// Prefer stack navigation when either axis is compact (e.g. iPhone landscape reports regular width + compact height).
    package static func useCompactNavigation(
        horizontalIsCompact: Bool,
        verticalIsCompact: Bool,
        platformIsIOS: Bool
    ) -> Bool {
        if platformIsIOS {
            if horizontalIsCompact { return true }
            if verticalIsCompact { return true }
            return false
        }
        return horizontalIsCompact
    }

    /// Tighter chrome when vertical space is compact (e.g. iPhone landscape).
    package static func explorerTightVertical(verticalIsCompact: Bool, platformIsIOS: Bool) -> Bool {
        platformIsIOS && verticalIsCompact
    }
}
