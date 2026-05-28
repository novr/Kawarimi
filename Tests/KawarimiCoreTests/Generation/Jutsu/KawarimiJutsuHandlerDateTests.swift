import Foundation
@testable import KawarimiJutsu
import Testing

struct InlineDateExampleCase: Sendable {
    let fixtureName: String
    let witnessName: String
    let forbiddenSubstrings: [String]
}

private let inlineDateExampleCases: [InlineDateExampleCase] = [
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-response",
        witnessName: "onGetSnapshot",
        forbiddenSubstrings: ["updatedAt: \"2025"]
    ),
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-edge-zulu",
        witnessName: "onGetDateTimeZulu",
        forbiddenSubstrings: ["t: \"2025"]
    ),
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-edge-fractional",
        witnessName: "onGetDateTimeFractional",
        forbiddenSubstrings: ["t: \"2025"]
    ),
    InlineDateExampleCase(
        fixtureName: "openapi-datetime-edge-date-only",
        witnessName: "onGetDateOnlyField",
        forbiddenSubstrings: ["day: \"2025"]
    ),
]

struct InlineDateWarningCase: Sendable {
    let fixtureName: String
    let witnessName: String
    let operationId: String
    let warningSubstring: String
}

private let inlineDateWarningCases: [InlineDateWarningCase] = [
    InlineDateWarningCase(
        fixtureName: "openapi-datetime-no-example",
        witnessName: "onGetSnapshotNoExample",
        operationId: "getSnapshotNoExample",
        warningSubstring: "epoch 0"
    ),
    InlineDateWarningCase(
        fixtureName: "openapi-datetime-edge-unparseable",
        witnessName: "onGetDateTimeUnparseable",
        operationId: "getDateTimeUnparseable",
        warningSubstring: "parse failed"
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
        forbiddenSubstrings: sample.forbiddenSubstrings
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
    KawarimiJutsuTestSupport.assertHandlerInlineDateStub(source: source, witnessName: sample.witnessName)
    #expect(source.contains("Date(timeIntervalSince1970: 0)"))
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
