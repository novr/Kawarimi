import KawarimiCore
import Testing
@testable import KawarimiHengeCore

@Test func kawarimiConfigReloadPresentationNoticeMessages() {
    #expect(
        KawarimiConfigReloadPresentation.noticeMessage(for: .applied)
            == "Reload applied: server re-read kawarimi.json."
    )
    #expect(
        KawarimiConfigReloadPresentation.noticeMessage(for: .unchanged)
            == "Reload unchanged: server already matched kawarimi.json."
    )
}

@Test func kawarimiConfigReloadPresentationLocalNoticeMessages() {
    #expect(
        KawarimiConfigReloadPresentation.localNoticeMessage(for: .unchanged, persistence: .memoryOnly)
            == "Reload skipped: memory-only store keeps unsaved edits."
    )
    #expect(
        KawarimiConfigReloadPresentation.localNoticeMessage(for: .applied, persistence: .disk)
            == "Reload applied: re-read kawarimi.json."
    )
    #expect(
        KawarimiConfigReloadPresentation.localNoticeMessage(for: .unchanged, persistence: .disk)
            == "Reload unchanged: already matched kawarimi.json."
    )
}
