import Foundation
import KawarimiJutsu
import Testing

@Test func generateKawarimiHandlerSourceEmitsMissingOperationIdSkipWarning() throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kawarimi-opid-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let yaml = """
    openapi: 3.0.3
    info: { title: T, version: '1' }
    paths:
      /no-id:
        get:
          responses:
            '200':
              description: ok
              content:
                application/json:
                  schema:
                    type: object
      /has-id:
        post:
          operationId: createThing
          responses:
            '201':
              description: created
              content:
                application/json:
                  schema:
                    type: object
    """
    let path = tmp.appendingPathComponent("openapi.yaml").path
    try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: path)
    let (_, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.first == "[kawarimi] warning: operation GET /no-id has no operationId and will be skipped")
}

@Test func kawarimiJutsuGenerateKawarimiHandlerSource() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml") else {
        Issue.record("openapi.yaml not found in test resources")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)

    #expect(source.contains("public struct KawarimiHandler"))
    #expect(source.contains("APIProtocol"))
    #expect(source.contains("public var onGetGreeting:"))
    #expect(source.contains("try await onGetGreeting(input)"))
    #expect(source.contains("getGreeting"))
    #expect(source.contains("listItems"))
    #expect(source.contains("createItem"))
    #expect(source.contains("getItem"))
    #expect(source.contains("deleteItem"))
    #expect(source.contains("listTags"))
    #expect(source.contains(".ok("))
    #expect(source.contains(".created("))
    #expect(source.contains(".noContent("))
    #expect(source.contains("@Sendable"))
    #expect(source.contains("import OpenAPIRuntime"))
    #expect(source.contains("Operations.getGreeting"))
}

@Test func kawarimiJutsuHandlerUsesIdiomaticOperationsTypeNames() throws {
    guard let openAPIURL = KawarimiJutsuTestSupport.fixtureURL(name: "openapi", extension: "yaml", subdirectory: "Fixtures/IdiomaticConfig") else {
        Issue.record("IdiomaticConfig/openapi.yaml not found")
        return
    }
    let strategy = try KawarimiNamingStrategy.loadBesideOpenAPIYAML(atPath: openAPIURL.path)
    #expect(strategy == .idiomatic)
    let document = try KawarimiJutsu.loadOpenAPISpec(path: openAPIURL.path)
    let (source, _) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: strategy)
    #expect(source.contains("Operations.GetGreeting"))
    #expect(source.contains("func getGreeting"))
    #expect(source.contains("public var onGetGreeting:"))
    #expect(source.contains("try await onGetGreeting(input)"))
}

@Test func kawarimiHandlerSupports200WithNoContentBlock() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-200-no-json", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, _) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(source.contains("agreeToTerms"))
    #expect(source.contains("return .ok(.init())"))
}

@Test func kawarimiHandlerDateTimeStubUsesTimeIntervalLiteralNotString() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-response", extension: "yaml") else {
        Issue.record("openapi-datetime-response.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onGetSnapshot"))
    #expect(source.contains("Date(timeIntervalSince1970:"))
    #expect(!source.contains("updatedAt: \"2025"))
    #expect(!source.contains("_kawarimiStubData"))
}

@Test func kawarimiHandlerDateTimeDecodeFixtureUsesJSONDecodeStubNotLiteral() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-handler-decode", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("_kawarimiStubData"))
    #expect(!source.contains("Date(timeIntervalSince1970:"))
}

@Test func kawarimiHandlerDateTimeWithoutExampleEmitsWarningAndEpochZero() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-no-example", extension: "yaml") else {
        Issue.record("openapi-datetime-no-example.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains("epoch 0"))
    #expect(warnings.joined().contains("getSnapshotNoExample"))
    #expect(source.contains("onGetSnapshotNoExample"))
    #expect(source.contains("Date(timeIntervalSince1970: 0)"))
}

@Test func kawarimiHandlerDateTimeEdgeZuluExampleUsesEpochLiteralNotString() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-zulu", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onGetDateTimeZulu"))
    #expect(source.contains("Date(timeIntervalSince1970:"))
    #expect(!source.contains("t: \"2025"))
}

@Test func kawarimiHandlerDateTimeEdgeFractionalSecondsUsesEpochLiteral() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-fractional", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onGetDateTimeFractional"))
    #expect(source.contains("Date(timeIntervalSince1970:"))
    #expect(!source.contains("t: \"2025"))
}

@Test func kawarimiHandlerDateOnlyFormatUsesEpochLiteralNotString() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-date-only", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onGetDateOnlyField"))
    #expect(source.contains("Date(timeIntervalSince1970:"))
    #expect(!source.contains("day: \"2025"))
}

@Test func kawarimiHandlerDateTimeUnparseableExampleEmitsWarningAndEpochZero() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-unparseable", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains("parse failed"))
    #expect(warnings.joined().contains("getDateTimeUnparseable"))
    #expect(source.contains("onGetDateTimeUnparseable"))
    #expect(source.contains("Date(timeIntervalSince1970: 0)"))
}

@Test func kawarimiHandlerDateTimeNestedPropertiesEachEmitDateLiteral() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-nested", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onGetDateTimeNested"))
    #expect(source.contains("createdAt: Date(timeIntervalSince1970:"))
    #expect(source.contains("updatedAt: Date(timeIntervalSince1970:"))
    #expect(!source.contains("createdAt: \"2020"))
    #expect(!source.contains("updatedAt: \"2025"))
}

@Test func kawarimiHandlerDateTime201CreatedBodyUsesDateLiteral() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-created", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onPostDateTimeCreated"))
    #expect(source.contains(".created("))
    #expect(source.contains("Date(timeIntervalSince1970:"))
    #expect(!source.contains("at: \"2030"))
}

@Test func kawarimiHandlerDateTimeArrayItemsUseDateLiteral() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-edge-array", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onGetDateTimeArray"))
    #expect(source.contains("[Date(timeIntervalSince1970:"))
    #expect(!source.contains("\"2024-01-01"))
}

@Test func kawarimiHandlerUsesJSONDecodeStubForStringEnumWhenPolicyIsFatalError() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        handlerStubPolicy: .fatalError
    )
    #expect(source.contains("onCreateItem"))
    #expect(source.contains("_kawarimiStubJSONDecoder()"))
    #expect(source.contains("decode(Operations.createItem.Output.Created.Body.jsonPayload.self"))
    #expect(!source.contains("fatalError("))
    #expect(!source.contains("// Kawarimi: handlerStubPolicy fatalError"))
    #expect(warnings.isEmpty)
}

@Test func kawarimiHandlerUsesJSONDecodeStubWhenAccessInternalAndPolicyIsFatalError() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        accessModifier: .internal,
        handlerStubPolicy: .fatalError
    )
    #expect(source.contains("internal var onCreateItem:"))
    #expect(source.contains("_kawarimiStubJSONDecoder()"))
    #expect(!source.contains("fatalError("))
    #expect(warnings.isEmpty)
}

@Test func kawarimiHandlerUsesJSONDecodeStubForStringEnumWithDefaultThrowPolicy() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("_kawarimiStubJSONDecoder()"))
    #expect(source.contains("decode(Operations.createItem.Output.Created.Body.jsonPayload.self"))
}

@Test func kawarimiHandlerAllOfDateTimeUsesSharedStubJSONDecoder() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-handler-decode", extension: "yaml") else {
        Issue.record("openapi-datetime-handler-decode.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("_kawarimiStubJSONDecoder()"))
    #expect(source.contains("onGetSnapshotDecode"))
    #expect(source.contains("_kawarimiStubData = Data(\""))
    #expect(!source.contains("Date(timeIntervalSince1970:"))
    let stubJSON = try #require(handlerDecodeStubJSONString(witnessName: "onGetSnapshotDecode", in: source))
    #expect(stubJSON.contains("2025-02-14T00:30:00Z"))
    let decoded = try kawarimiStubJSONDecoderForTests().decode(
        DateTimeDecodePayload.self,
        from: Data(stubJSON.utf8)
    )
    #expect(decoded.updatedAt.timeIntervalSince1970 > 0)
}

@Test func kawarimiHandlerUsesFatalErrorStubForNonJsonSuccessWhenPolicyIsFatalError() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-xml-success-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        handlerStubPolicy: .fatalError
    )
    #expect(source.contains("fatalError("))
    #expect(source.contains("onGetReport"))
    #expect(source.contains("// Kawarimi: handlerStubPolicy fatalError"))
    #expect(source.contains("//   [GET /report] getReport"))
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains("getReport"))
    #expect(warnings.joined().contains("Kawarimi warning:"))
    #expect(warnings.joined().contains("Summary: 1 operation"))
}

