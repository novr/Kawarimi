import Foundation
import KawarimiJutsu
import Testing

@Test func kawarimiJutsuLoadsOpenAPI310Fixture() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-3.1.0", extension: "yaml") else {
        Issue.record("openapi-3.1.0.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateSwiftSource(document: document)
    #expect(transportResponseStatusSwiftName(operationId: "ping", in: source) == "ok")
    let json = try #require(transportMockBodyJSONString(operationId: "ping", in: source))
    try assertJSONDecoderAcceptsMockBody(json)
}

@Test func kawarimiJutsuLoadsOpenAPI320Fixture() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-3.2.0", extension: "yaml") else {
        Issue.record("openapi-3.2.0.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateSwiftSource(document: document)
    #expect(transportMockBodyJSONString(operationId: "ping", in: source) != nil)
}

@Test func kawarimiJutsuThrowsSpecParseErrorForInvalidYAML() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-bad-yaml-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let path = tmp.appendingPathComponent("openapi.yaml").path
    try "openapi: [ not: valid".write(toFile: path, atomically: true, encoding: .utf8)
    #expect(throws: KawarimiJutsuError.self) {
        _ = try KawarimiJutsu.loadOpenAPISpec(path: path)
    }
    do {
        _ = try KawarimiJutsu.loadOpenAPISpec(path: path)
        Issue.record("expected specParseError")
    } catch let error as KawarimiJutsuError {
        if case .specParseError = error {
            #expect(Bool(true))
        } else {
            Issue.record("unexpected error: \(error)")
        }
    }
}

@Test func kawarimiJutsuThrowsSpecParseErrorForUnsupportedOpenAPIVersion() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-bad-ver-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let path = tmp.appendingPathComponent("openapi.yaml").path
    try """
    openapi: 2.0
    info:
      title: T
      version: '1'
    paths: {}
    """.write(toFile: path, atomically: true, encoding: .utf8)
    do {
        _ = try KawarimiJutsu.loadOpenAPISpec(path: path)
        Issue.record("expected specParseError")
    } catch let error as KawarimiJutsuError {
        if case .specParseError(let message) = error {
            #expect(message.contains("Unsupported document version"))
        } else {
            Issue.record("unexpected error: \(error)")
        }
    }
}

@Test func resolveOpenAPISpecDocumentFindsSingleMatch() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-resolve-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let docURL = tmp.appendingPathComponent("openapi.json")
    try Data("{}".utf8).write(to: docURL)
    let other = tmp.appendingPathComponent("Other.swift")
    try Data("//x".utf8).write(to: other)
    let resolved = try OpenAPISpecDocumentURL.resolveOpenAPISpecDocument(
        inKnownFileURLs: [other, docURL],
        targetName: "TmpTarget"
    )
    #expect(resolved == docURL)
}

@Test func resolveOpenAPISpecDocumentThrowsWhenAmbiguous() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-amb-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let a = tmp.appendingPathComponent("openapi.yaml")
    let b = tmp.appendingPathComponent("openapi.json")
    try Data("openapi: 3.0.3\ninfo:\n  title: T\n  version: '1'\npaths: {}\n".utf8).write(to: a)
    try Data(#"{"openapi":"3.0.3","info":{"title":"T","version":"1"},"paths":{}}"#.utf8).write(to: b)
    #expect(throws: KawarimiJutsuError.self) {
        _ = try OpenAPISpecDocumentURL.resolveOpenAPISpecDocument(inKnownFileURLs: [a, b], targetName: "TmpTarget")
    }
}

@Test func resolveOpenAPISpecDocumentThrowsWhenMissing() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Kawarimi-miss-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let other = tmp.appendingPathComponent("Other.swift")
    try Data("//x".utf8).write(to: other)
    #expect(throws: KawarimiJutsuError.self) {
        _ = try OpenAPISpecDocumentURL.resolveOpenAPISpecDocument(inKnownFileURLs: [other], targetName: "TmpTarget")
    }
}
@Test func kawarimiJutsuThrowsWhenSpecNotFound() throws {
    #expect(throws: KawarimiJutsuError.self) {
        _ = try KawarimiJutsu.loadOpenAPISpec(path: "/nonexistent/openapi.yaml")
    }
}

@Test func kawarimiJutsuLoadsOpenAPIJSONFixture() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "json") else {
        Issue.record("openapi.json not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let source = KawarimiJutsu.generateSwiftSource(document: document)
    #expect(source.contains("case \"getGreeting\""))
    #expect(source.contains("case \"listItems\""))
}

