import KawarimiCore

package struct SecuritySchemeDetail: Sendable, Identifiable {
    package var id: String { name }
    package let name: String
    package let summary: String
    package let description: String?
}

package struct EndpointSecurityPresentation: Sendable {
    package let requirementLines: [String]
    package let schemeDetails: [SecuritySchemeDetail]

    package var hasContent: Bool {
        !requirementLines.isEmpty || !schemeDetails.isEmpty
    }
}

package enum SecurityPresentation {
    package static func schemeSummary(_ scheme: any SpecSecuritySchemeProviding) -> String {
        switch scheme.type {
        case "apiKey":
            let location = scheme.apiKeyIn ?? "?"
            let field = scheme.apiKeyName ?? "?"
            return "apiKey (\(location): \(field))"
        case "http":
            let schemeName = scheme.httpScheme ?? "http"
            if let format = scheme.bearerFormat, !format.isEmpty {
                return "http (\(schemeName), format: \(format))"
            }
            return "http (\(schemeName))"
        case "openIdConnect":
            if let url = scheme.openIdConnectURL, !url.isEmpty {
                return "openIdConnect (\(url))"
            }
            return "openIdConnect"
        case "oauth2":
            return "oauth2 (flows not expanded)"
        default:
            return scheme.type
        }
    }

    package static func formatScopedScheme(_ scoped: any SpecScopedSecuritySchemeProviding) -> String {
        guard let scopes = scoped.scopes, !scopes.isEmpty else {
            return scoped.name
        }
        return "\(scoped.name) (scopes: \(scopes.joined(separator: ", ")))"
    }

    package static func formatRequirement(_ requirement: any SpecSecurityRequirementProviding) -> String {
        requirement.schemeList.map(formatScopedScheme).joined(separator: " + ")
    }

    package static func requirementLines(for endpoint: any SpecEndpointProviding) -> [String] {
        guard let security = endpoint.security, !security.isEmpty else {
            return []
        }
        return security.map(formatRequirement)
    }

    package static func referencedSchemeNames(for endpoint: any SpecEndpointProviding) -> [String] {
        guard let security = endpoint.security else { return [] }
        var names: [String] = []
        var seen = Set<String>()
        for requirement in security {
            for scoped in requirement.schemeList {
                if seen.insert(scoped.name).inserted {
                    names.append(scoped.name)
                }
            }
        }
        return names
    }

    package static func schemeDetails(
        names: [String],
        catalog: [any SpecSecuritySchemeProviding]?
    ) -> [SecuritySchemeDetail] {
        guard let catalog, !catalog.isEmpty else { return [] }
        let byName = Dictionary(uniqueKeysWithValues: catalog.map { ($0.name, $0) })
        return names.compactMap { name in
            guard let scheme = byName[name] else {
                return SecuritySchemeDetail(
                    name: name,
                    summary: "definition not in catalog",
                    description: nil
                )
            }
            return SecuritySchemeDetail(
                name: name,
                summary: schemeSummary(scheme),
                description: scheme.description
            )
        }
    }

    package static func endpointPresentation(
        endpoint: any SpecEndpointProviding,
        catalog: [any SpecSecuritySchemeProviding]?
    ) -> EndpointSecurityPresentation {
        let lines = requirementLines(for: endpoint)
        let names = referencedSchemeNames(for: endpoint)
        let details = schemeDetails(names: names, catalog: catalog)
        return EndpointSecurityPresentation(requirementLines: lines, schemeDetails: details)
    }
}
