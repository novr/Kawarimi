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

    package static func refreshFailureMessage(after result: KawarimiConfigReloadResult, error: Error) -> String {
        "\(noticeMessage(for: result)) Failed to refresh overrides from status API: \(error.localizedDescription)"
    }
}
