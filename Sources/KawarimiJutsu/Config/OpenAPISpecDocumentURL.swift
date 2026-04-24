import Foundation

public enum OpenAPISpecDocumentURL {
    public static let supportedOpenAPIDocumentBasenames: Set<String> = [
        "openapi.yaml", "openapi.yml", "openapi.json",
    ]

    public static func resolveOpenAPISpecDocument(inKnownFileURLs urls: some Sequence<URL>, targetName: String) throws -> URL {
        let matches = urls.filter { supportedOpenAPIDocumentBasenames.contains($0.standardizedFileURL.lastPathComponent) }
        switch matches.count {
        case 0:
            throw KawarimiJutsuError.openapiGeneratorPluginFileLine(
                OpenAPIGeneratorFileErrorMessages.noOpenAPIDocument(targetName: targetName)
            )
        case 1:
            return matches[0]
        default:
            throw KawarimiJutsuError.openapiGeneratorPluginFileLine(
                OpenAPIGeneratorFileErrorMessages.multipleOpenAPIDocuments(targetName: targetName, files: matches)
            )
        }
    }
}
