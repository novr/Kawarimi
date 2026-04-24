import Foundation

public enum KawarimiGeneratorConfigSourceMessages {
    public static func multipleKawarimiGeneratorConfigs(targetName: String, files: [URL]) -> String {
        "Multiple kawarimi-generator-config files found in the target named '\(targetName)', but at most one is expected. Found \(files.map(\.path).joined(separator: " "))."
    }
}
