import Foundation
import _OpenAPIGeneratorCore

/// swift-openapi-generator Config に渡す値を OpenAPIGeneratorConfig から解決する責務のみを持つ。
public enum GeneratorConfigResolver {
    /// swift-openapi-generator config の generate を解決。未指定 or 空なら標準（types/client/server）。指定ありならそのリスト。Kawarimi.swift は常に出力する。
    public static func resolveGenerate(generatorConfig: OpenAPIGeneratorConfig?) -> [GeneratorMode] {
        guard let list = generatorConfig?.generate, !list.isEmpty else {
            return [.types, .client, .server]
        }
        return list.compactMap { GeneratorMode(rawValue: $0) }
    }

    /// swift-openapi-generator config の accessModifier を解決。省略時は internal。
    public static func resolveAccessModifier(generatorConfig: OpenAPIGeneratorConfig?) -> AccessModifier {
        guard let raw = generatorConfig?.accessModifier?.lowercased() else {
            return .internal
        }
        switch raw {
        case "package": return .package
        case "public": return .public
        default: return .internal
        }
    }

    /// swift-openapi-generator config の namingStrategy を解決。省略時はswift-openapi-generatorデフォルト。
    public static func resolveNamingStrategy(generatorConfig: OpenAPIGeneratorConfig?) -> NamingStrategy {
        guard let raw = generatorConfig?.namingStrategy?.lowercased() else {
            return Config.defaultNamingStrategy
        }
        switch raw {
        case "idiomatic": return .idiomatic
        default: return .defensive
        }
    }

    /// swift-openapi-generator config の filter を解決。DocumentFilterYAML をswift-openapi-generator DocumentFilter に変換する。未指定なら nil。
    public static func resolveFilter(generatorConfig: OpenAPIGeneratorConfig?) -> DocumentFilter? {
        guard let yaml = generatorConfig?.filter else { return nil }
        let ops = yaml.operations ?? []
        let tags = yaml.tags ?? []
        let schemas = yaml.schemas ?? []
        return DocumentFilter(operations: ops, tags: tags, schemas: schemas)
    }

    /// swift-openapi-generator config の featureFlags を解決。未指定なら空。
    public static func resolveFeatureFlags(generatorConfig: OpenAPIGeneratorConfig?) -> FeatureFlags {
        guard let list = generatorConfig?.featureFlags, !list.isEmpty else {
            return []
        }
        return Set(list.compactMap { FeatureFlag(rawValue: $0) })
    }
}
