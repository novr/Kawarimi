import KawarimiCore

package enum ParametersPresentation {
    /// Formatted parameter lines for documentation; `nil` when absent.
    package static func displayLines(for endpoint: any SpecEndpointProviding) -> [String]? {
        guard let parameters = endpoint.parameters, !parameters.isEmpty else { return nil }
        return parameters.map(displayLine(for:))
    }

    private static func displayLine(for parameter: SpecParameter) -> String {
        var parts = [parameter.location.rawValue, parameter.name]
        if let schemaType = parameter.schemaType, !schemaType.isEmpty {
            parts.append(schemaType)
        }
        parts.append(parameter.required ? "required" : "optional")
        return parts.joined(separator: " · ")
    }
}
