import Foundation
@testable import KawarimiJutsu
import Testing

@Test func handlerThrowPolicyFailsWhenResponseHasHeadersWithoutBody() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-handler-headers-no-body", extension: "yaml") else {
        Issue.record("openapi-handler-headers-no-body.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    do {
        _ = try KawarimiJutsu.generateKawarimiHandlerSource(
            document: document,
            namingStrategy: .defensive,
            handlerStubPolicy: .throw
        )
        Issue.record("expected handlerGenerationUnsupported")
    } catch let error as KawarimiJutsuError {
        if case .handlerGenerationUnsupported(let operationId, let detail) = error {
            #expect(operationId == "getHeadersNoBody")
            #expect(detail.contains("declares response headers but no body"))
        } else {
            Issue.record("unexpected error: \(error)")
        }
    }
}

@Test func kawarimiGeneratorConfigRejectsAllOutputsDisabled() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-no-outputs-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let openAPIPath = tmp.appendingPathComponent("openapi.yaml").path
    try """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths: {}
    """.write(toFile: openAPIPath, atomically: true, encoding: .utf8)

    let configPath = tmp.appendingPathComponent("kawarimi-generator-config.yaml").path
    try """
    generateKawarimi: false
    generateHandler: false
    generateSpec: false
    """.write(toFile: configPath, atomically: true, encoding: .utf8)

    do {
        _ = try KawarimiGeneratorConfigFileYAML.loadBesideOpenAPIYAML(atPath: openAPIPath)
        Issue.record("expected generatorConfigInvalid")
    } catch let error as KawarimiJutsuError {
        if case .generatorConfigInvalid(let path, let reason) = error {
            #expect(path == configPath)
            #expect(reason.contains("At least one"))
        } else {
            Issue.record("unexpected error: \(error)")
        }
    }
}

@Test func testingHookCanSurfaceIdiomaticInvariantViolation() throws {
    do {
        _ = try KawarimiNamingStrategy.testingForceIdiomaticInvariantViolation(documentedName: "DemoName")
        Issue.record("expected idiomaticNamingInvariantViolated")
    } catch let error as KawarimiJutsuError {
        if case .idiomaticNamingInvariantViolated(let documentedName) = error {
            #expect(documentedName == "DemoName")
        } else {
            Issue.record("unexpected error: \(error)")
        }
    }
}

@Test func testingMockJSONBodyReturnsWarningsForMissingDateExample() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-no-example", extension: "yaml") else {
        Issue.record("openapi-datetime-no-example.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let result = try #require(KawarimiJutsu.testingMockJSONBody(
        document: document,
        operationId: "getSnapshotNoExample",
        statusCode: 200
    ))
    #expect(result.body.contains("1970-01-01T00:00:00Z"))
    #expect(!result.warnings.isEmpty)
    let joined = result.warnings.joined(separator: "\n")
    #expect(joined.contains("getSnapshotNoExample"))
    #expect(joined.contains("epoch 0"))
}
