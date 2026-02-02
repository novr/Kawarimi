import Foundation
import Yams

/// 本家 openapi-generator-config 形式の YAML を読む責務のみを持つ。
public enum ConfigLoader {
    /// openapi パスから同じディレクトリの config を読む。kawarimi.yaml を優先し、なければ本家の openapi-generator-config.yaml をフォールバック。
    public static func load(openapiPath: String) -> OpenAPIGeneratorConfig? {
        let dir = URL(fileURLWithPath: openapiPath).deletingLastPathComponent().path
        let kawarimiPath = (dir as NSString).appendingPathComponent("kawarimi.yaml")
        let officialPath = (dir as NSString).appendingPathComponent("openapi-generator-config.yaml")

        if let config = loadFile(path: kawarimiPath) {
            return config
        }
        if let config = loadFile(path: officialPath) {
            return config
        }
        return nil
    }

    /// 指定パスの config ファイルをそのまま読む。プラグインから config パスを渡すときに使う。
    public static func load(configPath: String) -> OpenAPIGeneratorConfig? {
        loadFile(path: configPath)
    }

    private static func loadFile(path: String) -> OpenAPIGeneratorConfig? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        do {
            return try YAMLDecoder().decode(OpenAPIGeneratorConfig.self, from: content)
        } catch {
            return nil
        }
    }
}
