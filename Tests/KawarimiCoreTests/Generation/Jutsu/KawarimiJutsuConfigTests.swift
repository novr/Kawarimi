import Foundation
import KawarimiJutsu
import Testing

@Test func kawarimiJutsuErrorDescription() {
    let notFound = KawarimiJutsuError.specFileNotFound(path: "/foo")
    #expect(notFound.description.contains("not found"))
    #expect(notFound.description.contains("/foo"))
    let line = KawarimiJutsuError.openapiGeneratorPluginFileLine(
        OpenAPIGeneratorFileErrorMessages.noOpenAPIDocument(targetName: "MyTarget")
    )
    #expect(line.description == OpenAPIGeneratorFileErrorMessages.noOpenAPIDocument(targetName: "MyTarget"))
    let kawarimiLine = KawarimiJutsuError.kawarimiGeneratorConfigDiscovery(
        KawarimiGeneratorConfigSourceMessages.multipleKawarimiGeneratorConfigs(
            targetName: "T",
            files: [URL(fileURLWithPath: "/a.yaml"), URL(fileURLWithPath: "/b.yml")]
        )
    )
    #expect(
        kawarimiLine.description
            == KawarimiGeneratorConfigSourceMessages.multipleKawarimiGeneratorConfigs(
                targetName: "T",
                files: [URL(fileURLWithPath: "/a.yaml"), URL(fileURLWithPath: "/b.yml")]
            )
    )
}

@Test func kawarimiNamingStrategyRejectsUnknownValue() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiNaming-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let yaml = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try yaml.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "namingStrategy: fancy\n".write(toFile: config, atomically: true, encoding: .utf8)
    #expect(throws: KawarimiJutsuError.self) {
        _ = try KawarimiNamingStrategy.loadBesideOpenAPIYAML(atPath: openAPIPath)
    }
}

@Test func kawarimiHandlerStubPolicyInOpenAPIGeneratorConfigIsIgnoredAndDefaultsToThrow() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiStubPolicy-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let spec = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try spec.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "handlerStubPolicy: fatalError\n".write(toFile: config, atomically: true, encoding: .utf8)
    let loaded = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
    #expect(loaded.handlerStubPolicy == .throw)
}

@Test func kawarimiHandlerStubPolicyDefaultsToThrowWhenGeneratorKeyOmitted() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiStubOmit-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let spec = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try spec.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "namingStrategy: defensive\n".write(toFile: config, atomically: true, encoding: .utf8)
    let loaded = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
    #expect(loaded.handlerStubPolicy == .throw)
}

@Test func kawarimiAccessModifierRejectsUnknownValue() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiAccess-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    let spec = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """
    try spec.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    let config = tmp.appendingPathComponent("openapi-generator-config.yaml").path
    try "accessModifier: fileprivate\n".write(toFile: config, atomically: true, encoding: .utf8)
    #expect(throws: KawarimiJutsuError.self) {
        _ = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
    }
}

@Test func handlerStubPolicyBesideOpenAPIThrowsWhenMultipleKawarimiConfigs() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-multi-kaw-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    try "openapi: 3.0.3\ninfo: { title: T, version: '1' }\npaths: {}\n".write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    try "handlerStubPolicy: throw\n".write(
        toFile: tmp.appendingPathComponent("kawarimi-generator-config.yaml").path,
        atomically: true,
        encoding: .utf8
    )
    try "handlerStubPolicy: fatalError\n".write(
        toFile: tmp.appendingPathComponent("kawarimi-generator-config.yml").path,
        atomically: true,
        encoding: .utf8
    )
    var caught: String?
    do {
        _ = try KawarimiGeneratorConfigFileYAML.handlerStubPolicyBesideOpenAPIYAML(
            atPath: openAPIPath,
            targetNameForErrorMessages: "DemoAPI"
        )
    } catch let e as KawarimiJutsuError {
        caught = e.description
    }
    let expected = KawarimiGeneratorConfigSourceMessages.multipleKawarimiGeneratorConfigs(
        targetName: "DemoAPI",
        files: [
            tmp.appendingPathComponent("kawarimi-generator-config.yaml"),
            tmp.appendingPathComponent("kawarimi-generator-config.yml"),
        ]
    )
    #expect(caught == expected)
}

@Test func loadBesideOpenAPIGeneratorConfigMissingMatchesUpstreamMessage() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-no-gen-cfg-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    try "openapi: 3.0.3\ninfo: { title: T, version: '1' }\npaths: {}\n".write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    var caught: String?
    do {
        _ = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(
            atPath: openAPIPath,
            targetNameForErrorMessages: "DemoAPI"
        )
    } catch let e as KawarimiJutsuError {
        caught = e.description
    }
    let expected = OpenAPIGeneratorFileErrorMessages.noConfigFileFound(targetName: "DemoAPI")
    #expect(caught == expected)
}

@Test func kawarimiAccessModifierAcceptsPackage() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("KawarimiAccessPkg-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    try """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths:
      /x:
        get:
          operationId: getX
          responses:
            '200':
              description: ok
              content:
                application/json:
                  schema:
                    type: object
    """.write(toFile: openAPIPath, atomically: true, encoding: .utf8)
    try """
    namingStrategy: defensive
    accessModifier: package
    """.write(toFile: tmp.appendingPathComponent("openapi-generator-config.yaml").path, atomically: true, encoding: .utf8)
    let loaded = try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
    #expect(loaded.accessModifier == .package)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: openAPIPath)
    let (source, _) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: loaded.namingStrategy,
        accessModifier: loaded.accessModifier
    )
    #expect(source.contains("package var onGetX:"))
    #expect(source.contains("package func getX"))
}

