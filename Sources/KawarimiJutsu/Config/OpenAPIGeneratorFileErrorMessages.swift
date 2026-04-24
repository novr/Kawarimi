import Foundation

public enum OpenAPIGeneratorFileErrorMessages {
    public static func noConfigFileFound(targetName: String) -> String {
        "No config file found in the target named '\(targetName)'. Add a file called 'openapi-generator-config.yaml' or 'openapi-generator-config.yml' to the target's source directory. See documentation for details."
    }

    public static func multipleConfigFiles(targetName: String, files: [URL]) -> String {
        "Multiple config files found in the target named '\(targetName)', but exactly one is expected. Found \(files.map(\.path).joined(separator: " "))."
    }

    public static func noOpenAPIDocument(targetName: String) -> String {
        "No OpenAPI document found in the target named '\(targetName)'. Add a file called 'openapi.yaml', 'openapi.yml' or 'openapi.json' (can also be a symlink) to the target's source directory. See documentation for details."
    }

    public static func multipleOpenAPIDocuments(targetName: String, files: [URL]) -> String {
        "Multiple OpenAPI documents found in the target named '\(targetName)', but exactly one is expected. Found \(files.map(\.path).joined(separator: " "))."
    }
}
