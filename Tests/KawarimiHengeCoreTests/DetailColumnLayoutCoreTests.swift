// Layout contract for detail column (#117): safeAreaInset toolbar, split panes, no layoutPriority(0) on header alone.
// Automated tests here cover numeric metrics only; SwiftUI hierarchy regressions need manual checks.

import Testing
@testable import KawarimiHengeCore

@Test func detailColumnBottomToolbarHeightTightVsRegular() {
    #expect(DetailColumnLayoutCore.bottomToolbarHeight(tightVertical: true) == 76)
    #expect(DetailColumnLayoutCore.bottomToolbarHeight(tightVertical: false) == 92)
}

@Test func detailColumnJsonEditorMinBodyHeightTightVsRegular() {
    #expect(DetailColumnLayoutCore.jsonEditorMinBodyHeight(tightVertical: true) == 4 * 18 + 16)
    #expect(DetailColumnLayoutCore.jsonEditorMinBodyHeight(tightVertical: false) == 8 * 18 + 24)
}

@Test func detailColumnJsonLineCountEmptyAndSingleLine() {
    #expect(DetailColumnLayoutCore.jsonLineCount(body: nil) == 1)
    #expect(DetailColumnLayoutCore.jsonLineCount(body: "") == 1)
    #expect(DetailColumnLayoutCore.jsonLineCount(body: "{}") == 1)
}

@Test func detailColumnJsonLineCountMultiline() {
    #expect(DetailColumnLayoutCore.jsonLineCount(body: "a\nb") == 2)
    #expect(DetailColumnLayoutCore.jsonLineCount(body: "a\nb\n") == 3)
}

@Test func detailColumnJsonLineCountLongBody() {
    let lines = (1...500).map(String.init).joined(separator: "\n")
    #expect(DetailColumnLayoutCore.jsonLineCount(body: lines) == 500)
}

@Test func detailColumnEditorLineCountRespectsMinimum() {
    #expect(DetailColumnLayoutCore.editorLineCount(bodyLineCount: 1, tightVertical: false) == 8)
    #expect(DetailColumnLayoutCore.editorLineCount(bodyLineCount: 20, tightVertical: false) == 20)
    #expect(DetailColumnLayoutCore.editorLineCount(bodyLineCount: 2, tightVertical: true) == 4)
}

@Test func detailColumnEditorContentHeightScalesWithLineCount() {
    #expect(DetailColumnLayoutCore.editorContentHeight(lineCount: 8) == 8 * 18 + 8)
    #expect(DetailColumnLayoutCore.editorContentHeight(lineCount: 1) == 18 + 8)
}

@Test func detailColumnEditorLineNumbersTextSingleLine() {
    #expect(DetailColumnLayoutCore.editorLineNumbersText(lineCount: 0) == "1")
    #expect(DetailColumnLayoutCore.editorLineNumbersText(lineCount: 1) == "1")
}

@Test func detailColumnEditorLineNumbersTextMultiline() {
    #expect(DetailColumnLayoutCore.editorLineNumbersText(lineCount: 3) == "1\n2\n3")
    let parts = DetailColumnLayoutCore.editorLineNumbersText(lineCount: 3).split(
        separator: "\n",
        omittingEmptySubsequences: false
    )
    #expect(parts.count == 3)
}

@Test func detailColumnEditorLineNumbersTextLong() {
    let text = DetailColumnLayoutCore.editorLineNumbersText(lineCount: 500)
    let parts = text.split(separator: "\n", omittingEmptySubsequences: false)
    #expect(parts.count == 500)
    #expect(parts.first == "1")
    #expect(parts.last == "500")
}
