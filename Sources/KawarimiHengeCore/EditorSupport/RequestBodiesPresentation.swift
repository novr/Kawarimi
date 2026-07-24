import KawarimiCore

package enum RequestBodiesPresentation {
    /// Formatted request-body lines for documentation; `nil` when absent.
    package static func displayLines(for endpoint: any SpecEndpointProviding) -> [String]? {
        guard let bodies = endpoint.requestBodies, !bodies.isEmpty else { return nil }
        return bodies.map(displayLine(for:))
    }

    private static func displayLine(for body: SpecRequestBody) -> String {
        var parts = [body.contentType, body.required ? "required" : "optional"]
        if let exampleId = normalizedExampleId(body.exampleId) {
            parts.append(exampleId)
        }
        if let description = body.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            parts.append(description)
        }
        return parts.joined(separator: " · ")
    }

    private static func normalizedExampleId(_ id: String?) -> String? {
        guard let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
