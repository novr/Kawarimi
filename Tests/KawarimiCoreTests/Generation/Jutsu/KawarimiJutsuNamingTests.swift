import Foundation
import KawarimiJutsu
import Testing

struct IdiomaticNamingCase: Sendable {
    let operationId: String
    let expectedType: String
    let expectedMethod: String
}

private let idiomaticNamingCases: [IdiomaticNamingCase] = [
    IdiomaticNamingCase(operationId: "getGreeting", expectedType: "GetGreeting", expectedMethod: "getGreeting"),
    IdiomaticNamingCase(operationId: "create_item", expectedType: "CreateItem", expectedMethod: "createItem"),
    IdiomaticNamingCase(operationId: "get-user-profile", expectedType: "GetUserProfile", expectedMethod: "getUserProfile"),
    IdiomaticNamingCase(operationId: "get_user_profile", expectedType: "GetUserProfile", expectedMethod: "getUserProfile"),
    IdiomaticNamingCase(operationId: "", expectedType: "_Empty_", expectedMethod: "_empty_"),
    IdiomaticNamingCase(operationId: "enum", expectedType: "Enum", expectedMethod: "_enum"),
    IdiomaticNamingCase(operationId: "GET", expectedType: "Get", expectedMethod: "get"),
    IdiomaticNamingCase(operationId: "GET_ALL", expectedType: "GetAll", expectedMethod: "getAll"),
    IdiomaticNamingCase(operationId: "listItems", expectedType: "ListItems", expectedMethod: "listItems"),
    IdiomaticNamingCase(operationId: "HTTPResponse", expectedType: "HTTPResponse", expectedMethod: "httpResponse"),
    IdiomaticNamingCase(operationId: "foo.bar.baz", expectedType: "Foo_bar_baz", expectedMethod: "foo_bar_baz"),
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
