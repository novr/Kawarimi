import Foundation
import KawarimiHengeCore
import SwiftUI

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
        Text(attributedLineNumbers)
            .frame(
                width: resolvedGutterWidth,
                height: CGFloat(max(lineCount, 1)) * lineHeight,
                alignment: .topTrailing
            )
            .padding(.vertical, verticalPadding)
            .fixedSize(horizontal: true, vertical: true)
    }

    private var resolvedGutterWidth: CGFloat {
        let digits = lineCount < 10 ? 1 : Int(log10(Double(lineCount))) + 1
        return max(gutterWidth, CGFloat(digits) * 9 + 6)
    }

    private var attributedLineNumbers: AttributedString {
        var text = AttributedString(DetailColumnLayoutCore.editorLineNumbersText(lineCount: lineCount))
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.lineBreakMode = .byClipping
        paragraph.alignment = .right
        text.paragraphStyle = paragraph
        text.font = .system(size: fontSize, design: .monospaced)
        text.foregroundColor = Color.white.opacity(foregroundOpacity)
        return text
    }
}
