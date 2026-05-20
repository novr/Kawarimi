import Foundation
import KawarimiCore

/// Shared labels and normalization for OpenAPI example rows in Henge.
package enum MockExamplePresentation {
    package static func normalizedExampleId(_ id: String?) -> String? {
        guard let t = id?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    package static func exampleIdsEqual(_ a: String?, _ b: String?) -> Bool {
        normalizedExampleId(a) == normalizedExampleId(b)
    }

    package static func label(for response: any SpecMockResponseProviding) -> String {
        if let ex = response.exampleId?.trimmingCharacters(in: .whitespacesAndNewlines), !ex.isEmpty {
            if let s = response.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return "\(ex) — \(s)"
            }
            return ex
        }
        return "Default"
    }

    package static func matchingPickerItem(exampleId: String?, in choices: [SpecMockResponseItem]) -> SpecMockResponseItem? {
        choices.first { exampleIdsEqual(exampleId, $0.response.exampleId) } ?? choices.first
    }
}
