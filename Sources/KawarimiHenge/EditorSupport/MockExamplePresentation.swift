import Foundation
import KawarimiCore

/// Shared labels and normalization for OpenAPI example rows in Henge.
enum MockExamplePresentation {
    static func normalizedExampleId(_ id: String?) -> String? {
        guard let t = id?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    static func exampleIdsEqual(_ a: String?, _ b: String?) -> Bool {
        normalizedExampleId(a) == normalizedExampleId(b)
    }

    static func label(for response: any SpecMockResponseProviding) -> String {
        if let ex = response.exampleId?.trimmingCharacters(in: .whitespacesAndNewlines), !ex.isEmpty {
            if let s = response.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return "\(ex) — \(s)"
            }
            return ex
        }
        return "Default"
    }

    static func matchingPickerItem(exampleId: String?, in choices: [SpecMockResponseItem]) -> SpecMockResponseItem? {
        choices.first { exampleIdsEqual(exampleId, $0.response.exampleId) } ?? choices.first
    }
}
