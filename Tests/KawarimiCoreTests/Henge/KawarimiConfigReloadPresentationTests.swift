import Foundation
import KawarimiCore
import Testing
@testable import KawarimiHengeCore

private struct MockRefreshError: Error, LocalizedError {
    var errorDescription: String? { "status fetch timeout" }
}

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

@Test func kawarimiConfigReloadPresentationRefreshFailureMessageIncludesOutcome() {
    let message = KawarimiConfigReloadPresentation.refreshFailureMessage(
        after: .applied,
        error: MockRefreshError()
    )
    #expect(message.contains("Reload applied"))
    #expect(message.contains("Failed to refresh overrides from status API"))
    #expect(message.contains("status fetch timeout"))
}
