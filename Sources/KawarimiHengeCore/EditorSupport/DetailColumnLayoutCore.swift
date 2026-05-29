import Foundation

// Bottom actions stay in safeAreaInset; header and JSON editor split the remaining height.
// Tall JSON scrolls inside the editor chrome (min height only); header scrolls in its own ScrollView.
// Never apply layoutPriority(0) to the header pane alone—it collapses to zero height.

/// Detail column layout metrics (unit-tested on Linux CI; no SwiftUI).
package enum DetailColumnLayoutCore {
    package static let editorLineHeight: Double = 18
    package static let editorContentVerticalPadding: Double = 8

    package static func bottomToolbarHeight(tightVertical: Bool) -> Double {
        tightVertical ? 76 : 92
    }

    package static func minDisplayLines(tightVertical: Bool) -> Int {
        tightVertical ? 4 : 8
    }

    package static func jsonEditorMinBodyHeight(tightVertical: Bool) -> Double {
        let minLines = Double(minDisplayLines(tightVertical: tightVertical))
        let verticalPad: Double = tightVertical ? 16 : 24
        return minLines * editorLineHeight + verticalPad
    }

    package static func jsonLineCount(body: String?) -> Int {
        let text = body ?? ""
        if text.isEmpty { return 1 }
        return max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    package static func editorLineCount(bodyLineCount: Int, tightVertical: Bool) -> Int {
        max(bodyLineCount, minDisplayLines(tightVertical: tightVertical))
    }

    package static func editorContentHeight(
        lineCount: Int,
        lineHeight: Double = editorLineHeight,
        verticalPadding: Double = editorContentVerticalPadding
    ) -> Double {
        Double(lineCount) * lineHeight + verticalPadding
    }

    package static func editorLineNumbersText(lineCount: Int) -> String {
        let n = max(lineCount, 1)
        guard n > 1 else { return "1" }
        var text = ""
        text.reserveCapacity(n * (Int(log10(Double(n))) + 2))
        for i in 1...n {
            if i > 1 { text.append("\n") }
            text.append(String(i))
        }
        return text
    }
}
