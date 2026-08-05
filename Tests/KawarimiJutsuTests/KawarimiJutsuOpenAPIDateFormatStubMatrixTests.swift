import Foundation
@testable import KawarimiJutsu
import Testing

/// OpenAPI absolute-date `format` → swift-openapi-generator Swift type → Kawarimi handler literal.
/// Locked to SOG Supported-OpenAPI-features: `date-time` → `Foundation.Date`; other formats
/// (including `date`) do not change the generated Swift type (`String`).
enum OpenAPIAbsoluteDateFormatContract: String, CaseIterable, Sendable {
    case dateTime = "date-time"
    case date = "date"

    /// Swift type assigned by swift-openapi-generator for this OpenAPI format.
    var sogSwiftType: String {
        switch self {
        case .dateTime: return "Date"
        case .date: return "String"
        }
    }

    /// Opposite SOG type — used to prove a wrong pairing fails `swiftc -typecheck` (#237 class of bug).
    var mismatchedSOGSwiftType: String {
        switch self {
        case .dateTime: return "String"
        case .date: return "Date"
        }
    }

    var expectsFoundationDateLiteral: Bool {
        self == .dateTime
    }

    var parseableExample: String {
        switch self {
        case .dateTime: return "2025-06-15T12:00:00Z"
        case .date: return "2025-11-30"
        }
    }

    var unparseableExample: String {
        "not-a-rfc3339-date"
    }

    var fallbackWarningSubstring: String {
        switch self {
        case .dateTime: return "epoch 0"
        case .date: return "fallback \"1970-01-01\""
        }
    }

    var fallbackArgumentExpression: String {
        switch self {
        case .dateTime: return "Date(timeIntervalSince1970: 0)"
        case .date: return "\"1970-01-01\""
        }
    }
}

enum OpenAPIAbsoluteDateExampleKind: String, CaseIterable, Sendable {
    case parseableExample
    case missingExample
    case unparseableExample
}

struct OpenAPIAbsoluteDateFormatStubMatrixCell: Sendable, CustomTestStringConvertible {
    let format: OpenAPIAbsoluteDateFormatContract
    let exampleKind: OpenAPIAbsoluteDateExampleKind

    var testDescription: String {
        "\(format.rawValue)/\(exampleKind.rawValue)"
    }

    var schemaExample: String? {
        switch exampleKind {
        case .parseableExample: return format.parseableExample
        case .missingExample: return nil
        case .unparseableExample: return format.unparseableExample
        }
    }

    var expectsWarnings: Bool {
        exampleKind != .parseableExample
    }
}

private let openAPIAbsoluteDateFormatStubMatrixCells: [OpenAPIAbsoluteDateFormatStubMatrixCell] =
    OpenAPIAbsoluteDateFormatContract.allCases.flatMap { format in
        OpenAPIAbsoluteDateExampleKind.allCases.map { exampleKind in
            OpenAPIAbsoluteDateFormatStubMatrixCell(format: format, exampleKind: exampleKind)
        }
    }

// Recurrence guard for #237: generated stub argument must typecheck as the SOG Swift type for that format.
@Suite("KawarimiJutsuOpenAPIDateFormatStubMatrix", .serialized)
struct KawarimiJutsuOpenAPIDateFormatStubMatrixTests {
    @Test(arguments: openAPIAbsoluteDateFormatStubMatrixCells)
    func kawarimiHandlerStubLiteralMatchesSOGTypeMatrix(
        cell: OpenAPIAbsoluteDateFormatStubMatrixCell
    ) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-date-format-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let yaml = KawarimiJutsuTestSupport.absoluteDateFormatOpenAPIYAML(
            format: cell.format.rawValue,
            example: cell.schemaExample
        )
        let path = tmp.appendingPathComponent("openapi.yaml").path
        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
        let document = try KawarimiJutsu.loadOpenAPISpec(path: path)
        let (source, warnings) = try KawarimiJutsu.generateKawarimiHandlerSource(
            document: document,
            namingStrategy: .defensive
        )

        if cell.expectsWarnings {
            #expect(!warnings.isEmpty)
            #expect(warnings.joined().contains(cell.format.fallbackWarningSubstring))
            #expect(warnings.joined().contains("getItem"))
            if cell.exampleKind == .unparseableExample {
                #expect(warnings.joined().contains("parse failed"))
            }
        } else {
            #expect(warnings.isEmpty)
        }

        let witness = try #require(handlerWitnessBlock(witnessName: "onGetItem", in: source))
        KawarimiJutsuTestSupport.assertHandlerInlineDateStub(
            source: source,
            witnessName: "onGetItem",
            expectsDateLiteral: cell.format.expectsFoundationDateLiteral
        )

        switch (cell.format, cell.exampleKind) {
        case (.dateTime, .parseableExample):
            #expect(witness.contains("value: Date(timeIntervalSince1970:"))
            #expect(!witness.contains("value: \"2025-06-15"))
        case (.dateTime, .missingExample), (.dateTime, .unparseableExample):
            #expect(witness.contains("value: \(cell.format.fallbackArgumentExpression)"))
        case (.date, .parseableExample):
            #expect(witness.contains("value: \"2025-11-30\""))
            #expect(!witness.contains("Date(timeIntervalSince1970:"))
        case (.date, .missingExample), (.date, .unparseableExample):
            #expect(witness.contains("value: \(cell.format.fallbackArgumentExpression)"))
            #expect(!witness.contains("Date(timeIntervalSince1970:"))
        }

        let generatedArgument = try #require(
            KawarimiJutsuTestSupport.extractLabeledArgumentExpression(label: "value", from: witness)
        )

        try KawarimiJutsuTestSupport.assertAbsoluteDateFormatStubTypechecks(
            sogSwiftType: cell.format.sogSwiftType,
            argumentExpression: generatedArgument
        )
        try KawarimiJutsuTestSupport.assertSwiftSnippetTypechecksExpectingFailure(
            """
            import Foundation
            struct StubBody {
                init(value: \(cell.format.mismatchedSOGSwiftType)) {}
            }
            let _ = StubBody(value: \(generatedArgument))
            """
        )
    }
}
