import Foundation
import KawarimiCore
import Testing
import _OpenAPIGeneratorCore

@Test func generatorConfigResolverResolveGenerateNilReturnsAllModes() {
    let modes = GeneratorConfigResolver.resolveGenerate(generatorConfig: nil)
    #expect(modes.count == 3)
    #expect(modes.contains(.types))
    #expect(modes.contains(.client))
    #expect(modes.contains(.server))
}

@Test func generatorConfigResolverResolveGenerateWithTypesOnly() {
    let config = OpenAPIGeneratorConfig(generate: ["types"])
    let modes = GeneratorConfigResolver.resolveGenerate(generatorConfig: config)
    #expect(modes == [.types])
}

@Test func generatorConfigResolverResolveAccessModifierNilReturnsInternal() {
    let access = GeneratorConfigResolver.resolveAccessModifier(generatorConfig: nil)
    #expect(access == .internal)
}

@Test func generatorConfigResolverResolveAccessModifierPublic() {
    let config = OpenAPIGeneratorConfig(accessModifier: "public")
    let access = GeneratorConfigResolver.resolveAccessModifier(generatorConfig: config)
    #expect(access == .public)
}

@Test func generatorConfigResolverResolveAccessModifierPackage() {
    let config = OpenAPIGeneratorConfig(accessModifier: "package")
    let access = GeneratorConfigResolver.resolveAccessModifier(generatorConfig: config)
    #expect(access == .package)
}

@Test func generatorConfigResolverResolveNamingStrategyNilReturnsDefault() {
    let strategy = GeneratorConfigResolver.resolveNamingStrategy(generatorConfig: nil)
    #expect(strategy == Config.defaultNamingStrategy)
}

@Test func generatorConfigResolverResolveNamingStrategyIdiomatic() {
    let config = OpenAPIGeneratorConfig(namingStrategy: "idiomatic")
    let strategy = GeneratorConfigResolver.resolveNamingStrategy(generatorConfig: config)
    #expect(strategy == .idiomatic)
}

@Test func generatorConfigResolverResolveNamingStrategyDefensive() {
    let config = OpenAPIGeneratorConfig(namingStrategy: "defensive")
    let strategy = GeneratorConfigResolver.resolveNamingStrategy(generatorConfig: config)
    #expect(strategy == .defensive)
}

@Test func generatorConfigResolverResolveFilterNilReturnsNil() {
    let filter = GeneratorConfigResolver.resolveFilter(generatorConfig: nil)
    #expect(filter == nil)
}

@Test func generatorConfigResolverResolveFilterWithYamlReturnsDocumentFilter() {
    let yaml = DocumentFilterYAML(operations: ["getGreeting"], tags: ["Greetings"], schemas: nil)
    let config = OpenAPIGeneratorConfig(filter: yaml)
    let filter = GeneratorConfigResolver.resolveFilter(generatorConfig: config)
    #expect(filter != nil)
    #expect(filter?.operations == ["getGreeting"])
    #expect(filter?.tags == ["Greetings"])
    #expect(filter?.schemas == [])
}

@Test func generatorConfigResolverResolveFeatureFlagsNilReturnsEmpty() {
    let flags = GeneratorConfigResolver.resolveFeatureFlags(generatorConfig: nil)
    #expect(flags.isEmpty)
}

@Test func generatorConfigResolverResolveFeatureFlagsEmptyListReturnsEmpty() {
    let config = OpenAPIGeneratorConfig(featureFlags: [])
    let flags = GeneratorConfigResolver.resolveFeatureFlags(generatorConfig: config)
    #expect(flags.isEmpty)
}
