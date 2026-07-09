import Foundation
import KawarimiJutsu
import Testing

struct IdiomaticNamingCase: Sendable {
    let operationId: String
    let expectedType: String
    let expectedMethod: String
}

// SOG basis:
// - swift-openapi-generator PR #679 SafeNameGenerator tests:
//   https://github.com/apple/swift-openapi-generator/pull/679
// - vectors include: Hello world, hello-world, Retry-After, HELLO_WORLD,
//   HTTPProxy, HTTP_Proxy, HTTP_proxy, version 2.0, V1.2Release, get/pets/{petId}/notifications
// - dot handling for idiomatic naming is specified by SafeNameGenerator behavior where "." is mapped to "_"
//   before defensive sanitization; therefore foo.bar.baz is fixed to foo_bar_baz / Foo_bar_baz.
private let idiomaticNamingCases: [IdiomaticNamingCase] = [
    IdiomaticNamingCase(operationId: "Hello world", expectedType: "HelloWorld", expectedMethod: "helloWorld"),
    IdiomaticNamingCase(operationId: "hello-world", expectedType: "HelloWorld", expectedMethod: "helloWorld"),
    IdiomaticNamingCase(operationId: "Retry-After", expectedType: "RetryAfter", expectedMethod: "retryAfter"),
    IdiomaticNamingCase(operationId: "HELLO_WORLD", expectedType: "HelloWorld", expectedMethod: "helloWorld"),
    IdiomaticNamingCase(operationId: "HELLO", expectedType: "Hello", expectedMethod: "hello"),
    IdiomaticNamingCase(operationId: "HTTPProxy", expectedType: "HTTPProxy", expectedMethod: "httpProxy"),
    IdiomaticNamingCase(operationId: "HTTP_Proxy", expectedType: "HTTPProxy", expectedMethod: "httpProxy"),
    IdiomaticNamingCase(operationId: "HTTP_proxy", expectedType: "HTTPProxy", expectedMethod: "httpProxy"),
    IdiomaticNamingCase(operationId: "version 2.0", expectedType: "Version2_0", expectedMethod: "version2_0"),
    IdiomaticNamingCase(operationId: "V1.2Release", expectedType: "V1_2Release", expectedMethod: "v1_2Release"),
    IdiomaticNamingCase(operationId: "get/pets/{petId}/notifications", expectedType: "GetPetsPetIdNotifications", expectedMethod: "getPetsPetIdNotifications"),
    IdiomaticNamingCase(operationId: "foo.bar.baz", expectedType: "Foo_bar_baz", expectedMethod: "foo_bar_baz"),
    IdiomaticNamingCase(operationId: "", expectedType: "_Empty_", expectedMethod: "_empty_"),
    IdiomaticNamingCase(operationId: "123start", expectedType: "_123start", expectedMethod: "_123start"),
]

struct DefensiveNamingCase: Sendable {
    let operationId: String
    let expectedType: String
    let expectedMethod: String
}

private let defensiveNamingCases: [DefensiveNamingCase] = [
    DefensiveNamingCase(operationId: "getGreeting", expectedType: "getGreeting", expectedMethod: "getGreeting"),
    DefensiveNamingCase(operationId: "create-item", expectedType: "create_hyphen_item", expectedMethod: "create_hyphen_item"),
    DefensiveNamingCase(operationId: "enum", expectedType: "_enum", expectedMethod: "_enum"),
]

@Test(arguments: idiomaticNamingCases)
func kawarimiNamingStrategyIdiomaticMapsOperationId(case sample: IdiomaticNamingCase) throws {
    let strategy = KawarimiNamingStrategy.idiomatic
    #expect(try strategy.swiftOperationTypeName(forOperationId: sample.operationId) == sample.expectedType)
    #expect(try strategy.swiftOperationMethodName(forOperationId: sample.operationId) == sample.expectedMethod)
}

@Test(arguments: defensiveNamingCases)
func kawarimiNamingStrategyDefensiveMapsOperationId(case sample: DefensiveNamingCase) throws {
    let strategy = KawarimiNamingStrategy.defensive
    #expect(try strategy.swiftOperationTypeName(forOperationId: sample.operationId) == sample.expectedType)
    #expect(try strategy.swiftOperationMethodName(forOperationId: sample.operationId) == sample.expectedMethod)
}

struct SchemaTypeNamingCase: Sendable {
    let schemaName: String
    let expectedType: String
}

private let defensiveSchemaTypeNamingCases: [SchemaTypeNamingCase] = [
    SchemaTypeNamingCase(schemaName: "Error", expectedType: "_Error"),
    SchemaTypeNamingCase(schemaName: "enum", expectedType: "_enum"),
    SchemaTypeNamingCase(schemaName: "create-item", expectedType: "create_hyphen_item"),
    SchemaTypeNamingCase(schemaName: "retry-after", expectedType: "retry_hyphen_after"),
    SchemaTypeNamingCase(schemaName: "123Status", expectedType: "_123Status"),
]

private let idiomaticSchemaTypeNamingCases: [SchemaTypeNamingCase] = [
    SchemaTypeNamingCase(schemaName: "Error", expectedType: "_Error"),
    SchemaTypeNamingCase(schemaName: "hello-world", expectedType: "HelloWorld"),
    SchemaTypeNamingCase(schemaName: "retry-after", expectedType: "RetryAfter"),
    SchemaTypeNamingCase(schemaName: "123Status", expectedType: "_123Status"),
]

@Test(arguments: defensiveSchemaTypeNamingCases)
func kawarimiNamingStrategyDefensiveMapsSchemaTypeName(case sample: SchemaTypeNamingCase) throws {
    let strategy = KawarimiNamingStrategy.defensive
    #expect(try strategy.swiftSchemaTypeName(for: sample.schemaName) == sample.expectedType)
}

@Test(arguments: idiomaticSchemaTypeNamingCases)
func kawarimiNamingStrategyIdiomaticMapsSchemaTypeName(case sample: SchemaTypeNamingCase) throws {
    let strategy = KawarimiNamingStrategy.idiomatic
    #expect(try strategy.swiftSchemaTypeName(for: sample.schemaName) == sample.expectedType)
}

struct MemberNameCase: Sendable {
    let raw: String
    let expected: String
}

// Reserved property names must be escaped the same way for member (argument-label) names as
// swift-openapi-generator escapes struct members; these all map identically under both strategies
// because they are single lowercase words (idiomatic leaves them unchanged, then escapes reserved).
private let reservedMemberNameCases: [MemberNameCase] = [
    MemberNameCase(raw: "type", expected: "_type"),
    MemberNameCase(raw: "protocol", expected: "_protocol"),
    MemberNameCase(raw: "self", expected: "_self"),
    MemberNameCase(raw: "default", expected: "_default"),
    MemberNameCase(raw: "normal", expected: "normal"),
]

@Test(arguments: reservedMemberNameCases)
func kawarimiNamingStrategyDefensiveEscapesReservedMemberName(case sample: MemberNameCase) throws {
    #expect(try KawarimiNamingStrategy.defensive.swiftMemberName(for: sample.raw) == sample.expected)
}

@Test(arguments: reservedMemberNameCases)
func kawarimiNamingStrategyIdiomaticEscapesReservedMemberName(case sample: MemberNameCase) throws {
    #expect(try KawarimiNamingStrategy.idiomatic.swiftMemberName(for: sample.raw) == sample.expected)
}

@Test func kawarimiJutsuHandlerUsesIdiomaticOperationsTypeNames() throws {
    guard let openAPIURL = KawarimiJutsuTestSupport.fixtureURL(
        name: "openapi",
        extension: "yaml",
        subdirectory: "Fixtures/IdiomaticConfig"
    ) else {
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
