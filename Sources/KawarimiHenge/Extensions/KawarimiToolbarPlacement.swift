import SwiftUI

extension ToolbarItemPlacement {
    /// `navigationBarTrailing` is unavailable on macOS.
    static var kawarimiTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarTrailing
        #else
        .primaryAction
        #endif
    }
}
