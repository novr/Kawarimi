import Foundation
@testable import KawarimiJutsu
import Testing

struct InlineDateExampleCase: Sendable {
    let fixtureName: String
    let witnessName: String
    let forbiddenSubstrings: [String]
    let requiredSubstrings: [String]
    let expectsDateLiteral: Bool
}

private let inlineDateExampleCases: [InlineDateExampleCase] = [
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-response",
        witnessName: "onGetSnapshot",
        forbiddenSubstrings: ["updatedAt: \"2025"],
        requiredSubstrings: [],
        expectsDateLiteral: true
    ),
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-edge-zulu",
        witnessName: "onGetDateTimeZulu",
        forbiddenSubstrings: ["t: \"2025"],
        requiredSubstrings: [],
        expectsDateLiteral: true
    ),
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-edge-fractional",
        witnessName: "onGetDateTimeFractional",
        forbiddenSubstrings: ["t: \"2025"],
        requiredSubstrings: [],
        expectsDateLiteral: true
    ),
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-edge-date-only",
        witnessName: "onGetDateOnlyField",
        forbiddenSubstrings: ["Date(timeIntervalSince1970:"],
        requiredSubstrings: ["day: \"2025-11-30\""],
        expectsDateLiteral: false
    ),
]

struct InlineDateWarningCase: Sendable {
    let fixtureName: String
    let witnessName: String
    let operationId: String
    let warningSubstring: String
    let expectedFallbackSubstring: String
}

private let inlineDateWarningCases: [InlineDateWarningCase] = [
    InlineDateWarningCase(
        fixtureName: "openapi-datetime-no-example",
        witnessName: "onGetSnapshotNoExample",
        operationId: "getSnapshotNoExample",
        warningSubstring: "epoch 0",
        expectedFallbackSubstring: "Date(timeIntervalSince1970: 0)"
    ),
    InlineDateWarningCase(
        fixtureName: "openapi-datetime-edge-unparseable",
        witnessName: "onGetDateTimeUnparseable",
        operationId: "getDateTimeUnparseable",
        warningSubstring: "parse failed",
        expectedFallbackSubstring: "Date(timeIntervalSince1970: 0)"
    ),
    InlineDateWarningCase(
        fixtureName: "openapi-datetime-edge-date-only-no-example",
        witnessName: "onGetDateOnlyNoExample",
        operationId: "getDateOnlyNoExample",
        warningSubstring: "epoch 0",
        expectedFallbackSubstring: "day: \"1970-01-01\""
    ),
]

struct InlineDateStructureCase: Sendable {
    let fixtureName: String
    let witnessName: String
    let forbiddenSubstrings: [String]
    let extraChecks: [String]
}

private let inlineDateStructureCases: [InlineDateStructureCase] = [
    InlineDateStructureCase(
        fixtureName: "openapi-datetime-edge-nested",
        witnessName: "onGetDateTimeNested",
        forbiddenSubstrings: ["createdAt: \"2020", "updatedAt: \"2025"],
        extraChecks: ["createdAt: Date(timeIntervalSince1970:", "updatedAt: Date(timeIntervalSince1970:"]
    ),
    InlineDateStructureCase(
        fixtureName: "openapi-datetime-edge-array",
        witnessName: "onGetDateTimeArray",
        forbiddenSubstrings: ["\"2024-01-01"],
        extraChecks: ["[Date(timeIntervalSince1970:"]
    ),
    InlineDateStructureCase(
        fixtureName: "openapi-datetime-edge-created",
        witnessName: "onPostDateTimeCreated",
        forbiddenSubstrings: ["at: \"2030"],
        extraChecks: [".created(", "Date(timeIntervalSince1970:"]
    ),
]

@Test(arguments: inlineDateExampleCases)
func kawarimiHandlerInlineDateLiteralWithExample(case sample: InlineDateExampleCase) throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: sample.fixtureName, extension: "yaml") else {
        Issue.record("\(sample.fixtureName).yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    KawarimiJutsuTestSupport.assertHandlerInlineDateStub(
        source: source,
        witnessName: sample.witnessName,
        forbiddenSubstrings: sample.forbiddenSubstrings,
        requiredSubstrings: sample.requiredSubstrings,
        expectsDateLiteral: sample.expectsDateLiteral
    )
}

@Test(arguments: inlineDateWarningCases)
func kawarimiHandlerInlineDateWarningsAndEpochZero(case sample: InlineDateWarningCase) throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: sample.fixtureName, extension: "yaml") else {
        Issue.record("\(sample.fixtureName).yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(!warnings.isEmpty)
    #expect(warnings.joined().contains(sample.warningSubstring))
    #expect(warnings.joined().contains(sample.operationId))
    KawarimiJutsuTestSupport.assertHandlerInlineDateStub(
        source: source,
        witnessName: sample.witnessName,
        expectsDateLiteral: sample.expectedFallbackSubstring.contains("Date(timeIntervalSince1970:")
    )
    #expect(source.contains(sample.expectedFallbackSubstring))
}

@Test(arguments: inlineDateStructureCases)
func kawarimiHandlerInlineDateStructuredBodies(case sample: InlineDateStructureCase) throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: sample.fixtureName, extension: "yaml") else {
        Issue.record("\(sample.fixtureName).yaml not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(document: document, namingStrategy: .defensive)
    #expect(warnings.isEmpty)
    KawarimiJutsuTestSupport.assertHandlerInlineDateStub(
        source: source,
        witnessName: sample.witnessName,
        forbiddenSubstrings: sample.forbiddenSubstrings
    )
    for check in sample.extraChecks {
        #expect(source.contains(check))
    }
}

@Test func kawarimiHandlerFormatDateStubTypechecksAsString() throws {
    try KawarimiJutsuTestSupport.assertSwiftSnippetTypechecks(
        """
        struct StubBody {
            init(releasedOn: String) {}
        }
        let _ = StubBody(releasedOn: "2025-02-14")
        """
    )
}
