import Foundation
@testable import KawarimiJutsu
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
    #expect(source.contains("public var onCreateItem:"))
    #expect(source.contains("public var onDeleteItem:"))
    #expect(source.contains(".ok("))
    #expect(source.contains(".created("))
    #expect(source.contains(".noContent("))
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

struct EnumHandlerGenerationCase: Sendable {
    let accessModifier: KawarimiAccessModifier
    let handlerStubPolicy: KawarimiHandlerStubPolicy
    let witnessAccessKeyword: String
}

struct EnumCreateItemBody: Decodable {
    let status: String
}

private let enumHandlerGenerationCases: [EnumHandlerGenerationCase] = [
    EnumHandlerGenerationCase(accessModifier: .internal, handlerStubPolicy: .fatalError, witnessAccessKeyword: "internal"),
    EnumHandlerGenerationCase(accessModifier: .public, handlerStubPolicy: .throw, witnessAccessKeyword: "public"),
]

@Test(arguments: [KawarimiNamingStrategy.defensive, .idiomatic])
func kawarimiHandlerStubEscapesReservedPropertyNameLabel(strategy: KawarimiNamingStrategy) throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-reserved-property-name", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: strategy)
    #expect(warnings.isEmpty)
    // swift-openapi-generator escapes the reserved property name `type` to `_type`; the stub
    // initializer label must match, otherwise the generated handler fails to compile with
    // "incorrect argument label in call (have 'type:', expected '_type:')".
    #expect(source.contains(".init(_type: \"example-value\")"))
    #expect(!source.contains(".init(type:"))
}

@Test(arguments: enumHandlerGenerationCases)
func kawarimiHandlerUsesJSONDecodeStubForStringEnum(case config: EnumHandlerGenerationCase) throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-enum-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        accessModifier: config.accessModifier,
        handlerStubPolicy: config.handlerStubPolicy
    )
    #expect(source.contains("\(config.witnessAccessKeyword) var onCreateItem:"))
    #expect(!source.contains("fatalError("))
    #expect(warnings.isEmpty)
    try KawarimiJutsuTestSupport.assertHandlerDecodeStubMatchesSpec(
        witnessName: "onCreateItem",
        operationId: "createItem",
        document: document,
        source: source,
        decode: { data in
            let actualJSON = String(decoding: data, as: UTF8.self)
            try KawarimiJutsuTestSupport.expectNormalizedJSONEqual(actualJSON, #"{"status":"active"}"#)
            let decoded = try JSONDecoder().decode(EnumCreateItemBody.self, from: data)
            #expect(decoded.status == "active")
        }
    )
}

@Test(arguments: enumHandlerGenerationCases)
func kawarimiHandlerDecodeStubSanitizesKeywordSchemaName(case config: EnumHandlerGenerationCase) throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-enum-ref-keyword", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        accessModifier: config.accessModifier,
        handlerStubPolicy: config.handlerStubPolicy
    )
    #expect(warnings.isEmpty)
    let witnessBlock = try #require(handlerWitnessBlock(witnessName: "onCreateItem", in: source))
    #expect(witnessBlock.contains("Components.Schemas._Error.self"))
    #expect(!witnessBlock.contains("Components.Schemas.Error.self"))
}

struct SanitizedSchemaRefCase: Sendable {
    let witnessName: String
    let expectedDecodeType: String
    let forbiddenDecodeType: String
}

private let sanitizedSchemaRefCases: [SanitizedSchemaRefCase] = [
    SanitizedSchemaRefCase(
        witnessName: "onCreateItemHyphen",
        expectedDecodeType: "Components.Schemas.retry_hyphen_after.self",
        forbiddenDecodeType: "Components.Schemas.retry-after"
    ),
    SanitizedSchemaRefCase(
        witnessName: "onCreateItemDigit",
        expectedDecodeType: "Components.Schemas._123Status.self",
        forbiddenDecodeType: "Components.Schemas.123Status"
    ),
]

@Test(arguments: enumHandlerGenerationCases)
func kawarimiHandlerDecodeStubSanitizesHyphenAndDigitSchemaNames(case config: EnumHandlerGenerationCase) throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-enum-ref-sanitized-schema", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
        document: document,
        namingStrategy: .defensive,
        accessModifier: config.accessModifier,
        handlerStubPolicy: config.handlerStubPolicy
    )
    #expect(warnings.isEmpty)
    for sample in sanitizedSchemaRefCases {
        let witnessBlock = try #require(handlerWitnessBlock(witnessName: sample.witnessName, in: source))
        #expect(witnessBlock.contains(sample.expectedDecodeType))
        #expect(!witnessBlock.contains(sample.forbiddenDecodeType))
    }
}

@Test func kawarimiHandlerAllOfDateTimeUsesSharedStubJSONDecoder() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-datetime-handler-decode", extension: "yaml") else {
        Issue.record("openapi-datetime-handler-decode.yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    #expect(source.contains("onGetSnapshotDecode"))
    #expect(!source.contains("Date(timeIntervalSince1970:"))
    try KawarimiJutsuTestSupport.assertHandlerDecodeStubMatchesSpec(
        witnessName: "onGetSnapshotDecode",
        operationId: "getSnapshotDecode",
        document: document,
        source: source,
        decode: { data in
            let decoded = try OpenAPIDateMockSupport.stubJSONDecoder().decode(DateTimeDecodePayload.self, from: data)
            #expect(decoded.updatedAt.timeIntervalSince1970 > 0)
        }
    )
    let handlerJSON = try #require(handlerDecodeStubJSONString(witnessName: "onGetSnapshotDecode", in: source))
    try KawarimiJutsuTestSupport.expectGoldenJSON(operationId: "getSnapshotDecode", actual: handlerJSON)
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

