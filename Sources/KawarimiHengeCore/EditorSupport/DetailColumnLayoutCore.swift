import Foundation

// Bottom actions stay in safeAreaInset; the header scrolls in its own ScrollView.

/// Detail column layout metrics (unit-tested on Linux CI; no SwiftUI).
package enum DetailColumnLayoutCore {
    package static func bottomToolbarHeight(tightVertical: Bool) -> Double {
        tightVertical ? 76 : 92
    }
}
