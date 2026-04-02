import Foundation
import Yams

/// Optional `kawarimi-generator-config.yaml` / `kawarimi-generator-config.yml` beside `openapi.yaml` (Kawarimi generation-only keys).
public enum KawarimiGeneratorConfigFileYAML {
    /// Returns the config file path and trimmed `handlerStubPolicy` when present and non-empty.
    /// YAML decode failures return `nil` (treat as absent).
    public static func handlerStubPolicyBesideOpenAPIYAML(atPath openAPIYAMLPath: String) -> (path: String, value: String)? {
        let dir = URL(fileURLWithPath: openAPIYAMLPath).deletingLastPathComponent()
        let candidates = [
            dir.appendingPathComponent("kawarimi-generator-config.yaml"),
            dir.appendingPathComponent("kawarimi-generator-config.yml"),
        ]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = FileManager.default.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        struct Slice: Decodable {
            var handlerStubPolicy: String?
        }
        guard let slice = try? YAMLDecoder().decode(Slice.self, from: text) else {
            return nil
        }
        let raw = slice.handlerStubPolicy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return nil }
        return (url.path, raw)
    }
}
