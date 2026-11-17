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

    /// For an in-process store: there is no server, and a memory-only store never re-reads files.
    package static func localNoticeMessage(
        for result: KawarimiConfigReloadResult,
        persistence: KawarimiConfigPersistence
    ) -> String {
        switch (persistence, result) {
        case (.memoryOnly, _):
            "Reload skipped: memory-only store keeps unsaved edits."
        case (.disk, .applied):
            "Reload applied: re-read kawarimi.json."
        case (.disk, .unchanged):
            "Reload unchanged: already matched kawarimi.json."
        }
    }
}
