import KawarimiHengeCore
import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct JsonEditorLineNumberGutter: View {
    public let lineCount: Int
    public var lineHeight: CGFloat
    public var gutterWidth: CGFloat
    public var fontSize: CGFloat
    public var foregroundOpacity: Double
    public var verticalPadding: CGFloat

    public init(
        lineCount: Int,
        lineHeight: CGFloat = 18,
        gutterWidth: CGFloat = 36,
        fontSize: CGFloat = 13,
        foregroundOpacity: Double = 0.45,
        verticalPadding: CGFloat = 8
    ) {
        self.lineCount = lineCount
        self.lineHeight = lineHeight
        self.gutterWidth = gutterWidth
        self.fontSize = fontSize
        self.foregroundOpacity = foregroundOpacity
        self.verticalPadding = verticalPadding
    }

    public var body: some View {
        Text(DetailColumnLayoutCore.editorLineNumbersText(lineCount: lineCount))
            .font(.system(size: fontSize, design: .monospaced))
            .lineSpacing(extraLineSpacing)
            .foregroundStyle(Color.white.opacity(foregroundOpacity))
            .multilineTextAlignment(.trailing)
            .frame(width: gutterWidth, alignment: .trailing)
            .padding(.vertical, verticalPadding)
    }

    private var extraLineSpacing: CGFloat {
        max(0, lineHeight - monospacedFontLineHeight)
    }

    private var monospacedFontLineHeight: CGFloat {
        #if os(macOS)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return ceil(font.ascender - font.descender + font.leading)
        #elseif canImport(UIKit)
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return ceil(font.lineHeight)
        #else
        return fontSize
        #endif
    }
}
