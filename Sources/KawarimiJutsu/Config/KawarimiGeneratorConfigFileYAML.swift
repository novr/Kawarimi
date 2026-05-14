import Foundation
import Yams

public enum KawarimiGeneratorConfigFileYAML {
    public static func handlerStubPolicyBesideOpenAPIYAML(
        atPath openAPIYAMLPath: String,
        targetNameForErrorMessages: String? = nil
    ) throws -> (path: String, value: String)? {
        let dir = URL(fileURLWithPath: openAPIYAMLPath).deletingLastPathComponent()
        let targetName = targetNameForErrorMessages ?? dir.lastPathComponent
        let yamlURL = dir.appendingPathComponent("kawarimi-generator-config.yaml")
        let ymlURL = dir.appendingPathComponent("kawarimi-generator-config.yml")
        let existing = [yamlURL, ymlURL].filter { FileManager.default.fileExists(atPath: $0.path) }
        switch existing.count {
        case 0:
            return nil
        case 1:
            break
        default:
            throw KawarimiJutsuError.kawarimiGeneratorConfigDiscovery(
                KawarimiGeneratorConfigSourceMessages.multipleKawarimiGeneratorConfigs(
                    targetName: targetName,
                    files: existing
                )
            )
        }
        let url = existing[0]
        guard let data = FileManager.default.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        struct Slice: Decodable {
            var handlerStubPolicy: String?
        }
        do {
            let slice = try YAMLDecoder().decode(Slice.self, from: text)
            let raw = slice.handlerStubPolicy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty { return nil }
            return (url.path, raw)
        } catch {
            let path = url.path
            let msg = String(describing: error).replacingOccurrences(of: "\n", with: " ")
            fputs("Kawarimi warning: invalid kawarimi-generator-config YAML at \(path): \(msg)\n", stderr)
            return nil
        }
    }
}
