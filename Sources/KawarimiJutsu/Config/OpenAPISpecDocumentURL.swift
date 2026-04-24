import Foundation

/// OpenAPI document discovery for tests, CLI callers, and libraries. The build plugin duplicates the same rules (``supportedOpenAPIDocumentBasenames`` / single match) because SwiftPM does not allow build tool plugins to depend on library targets.
public enum OpenAPISpecDocumentURL {
    public static let supportedOpenAPIDocumentBasenames: Set<String> = [
        "openapi.yaml", "openapi.yml", "openapi.json",
    ]

    /// Resolves the OpenAPI document URL from paths known to SwiftPM (e.g. ``SwiftSourceModuleTarget/sourceFiles``), matching swift-openapi-generator `PluginUtils.findDocument`.
    public static func resolveOpenAPISpecDocument(inKnownFileURLs urls: some Sequence<URL>) throws -> URL {
        let matches = urls.filter { supportedOpenAPIDocumentBasenames.contains($0.standardizedFileURL.lastPathComponent) }
        switch matches.count {
        case 0:
            throw KawarimiJutsuError.openAPISpecDocumentMissing(
                allowedBasenames: supportedOpenAPIDocumentBasenames.sorted().joined(separator: ", ")
            )
        case 1:
            return matches[0]
        default:
            let paths = matches.map(\.path).sorted()
            throw KawarimiJutsuError.openAPISpecDocumentAmbiguous(paths: paths)
        }
    }
}
