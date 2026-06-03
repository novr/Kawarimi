import KawarimiCore

package enum KawarimiConfigReloadPresentation {
    package static func noticeMessage(for result: KawarimiConfigReloadResult) -> String {
        switch result {
        case .applied:
            "Reload applied: server re-read kawarimi.json."
        case .unchanged:
            "Reload unchanged: server already matched kawarimi.json."
        }
    }
}
