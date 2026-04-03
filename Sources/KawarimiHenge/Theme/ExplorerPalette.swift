import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

enum ExplorerPalette {
    #if os(iOS)
    private static let lightSurface = UIColor(red: 0.925, green: 0.929, blue: 0.98, alpha: 1)
    private static let lightSurfaceElevated = UIColor(red: 0.949, green: 0.953, blue: 1.0, alpha: 1)
    #endif

    static var surface: Color {
        #if os(iOS)
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? .systemGroupedBackground : lightSurface
        })
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var surfaceElevated: Color {
        #if os(iOS)
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : lightSurfaceElevated
        })
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var linkAccent: Color {
        #if os(iOS)
        Color(UIColor.link)
        #else
        Color(nsColor: .linkColor)
        #endif
    }

    static var subtleAccentFill: Color {
        Color.accentColor.opacity(0.14)
    }

    static var chipStripTray: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemFill)
        #else
        Color(nsColor: .quaternaryLabelColor).opacity(0.15)
        #endif
    }

    static var chipSelectedFill: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(nsColor: .selectedContentBackgroundColor)
        #endif
    }

    static var listCardFill: Color { surfaceElevated }

    static var groupedFieldStroke: Color {
        #if os(iOS)
        Color(UIColor.separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
}

struct ExplorerListRowCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ExplorerPalette.listCardFill)
            .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
    }
}
