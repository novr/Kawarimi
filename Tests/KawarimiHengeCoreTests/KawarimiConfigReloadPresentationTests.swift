import KawarimiCore
import Testing
@testable import KawarimiHengeCore

@Test(.timeLimit(.minutes(1))) func kawarimiConfigReloadPresentationNoticeMessages() {
    #expect(
        KawarimiConfigReloadPresentation.noticeMessage(for: .applied)
            == "Reload applied: server re-read kawarimi.json."
    )
    #expect(
        KawarimiConfigReloadPresentation.noticeMessage(for: .unchanged)
            == "Reload unchanged: server already matched kawarimi.json."
    )
}
