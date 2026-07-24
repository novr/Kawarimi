import Foundation

public enum SpecRequestBodySelection {
    /// Picks the default `application/json` request body row for Try-it and similar UIs.
    public static func preferredRequestBody(for endpoint: any SpecEndpointProviding) -> SpecRequestBody? {
        guard let bodies = endpoint.requestBodies, !bodies.isEmpty else { return nil }
        if let defaultRow = bodies.first(where: { normalizedExampleId($0.exampleId) == nil }) {
            return defaultRow
        }
        return bodies.first
    }

    /// Trimmed JSON text for the preferred request body, or `"{}"` when absent or empty.
    public static func defaultJSONBodyText(for endpoint: any SpecEndpointProviding) -> String {
        guard let trimmed = preferredRequestBody(for: endpoint)?
            .body
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else {
            return "{}"
        }
        return trimmed
    }

    private static func normalizedExampleId(_ id: String?) -> String? {
        guard let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
