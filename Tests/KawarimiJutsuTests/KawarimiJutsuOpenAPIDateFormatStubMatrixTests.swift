import Foundation
@testable import KawarimiJutsu
import Testing

// Recurrence guard for #237: generated stub argument must typecheck as the SOG Swift type for that format.
@Suite("KawarimiJutsuOpenAPIDateFormatStubMatrix", .serialized)
struct KawarimiJutsuOpenAPIDateFormatStubMatrixTests {
    /// OpenAPI absolute-date `format` → swift-openapi-generator Swift type → Kawarimi handler literal.
    /// Locked to SOG Supported-OpenAPI-features: `date-time` → `Foundation.Date`; other formats
    /// (including `date`) do not change the generated Swift type (`String`).
    enum FormatContract: String, CaseIterable, Sendable {
        case dateTime = "date-time"
        case date = "date"

        var sogSwiftType: String {
            switch self {
            case .dateTime: return "Date"
            case .date: return "String"
            }
        }

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

    enum ExampleKind: String, CaseIterable, Sendable {
        case parseableExample
        case missingExample
        case unparseableExample
    }

    struct Cell: Sendable, CustomTestStringConvertible {
        let format: FormatContract
        let exampleKind: ExampleKind

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

        /// Exact Swift argument when the generator's output is deterministic for this cell.
        var exactExpectedArgument: String? {
            switch (format, exampleKind) {
            case (.date, .parseableExample):
                return "\"\(format.parseableExample)\""
            case (.dateTime, .missingExample), (.dateTime, .unparseableExample),
                 (.date, .missingExample), (.date, .unparseableExample):
                return format.fallbackArgumentExpression
            case (.dateTime, .parseableExample):
                return nil
            }
        }
    }

    private static let cells: [Cell] = FormatContract.allCases.flatMap { format in
        ExampleKind.allCases.map { Cell(format: format, exampleKind: $0) }
    }

    @Test(arguments: cells)
    func kawarimiHandlerStubLiteralMatchesSOGTypeMatrix(cell: Cell) throws {
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

        // Guards against silently falling back to the decode-stub path.
        KawarimiJutsuTestSupport.assertHandlerInlineDateStub(
            source: source,
            witnessName: "onGetItem",
            expectsDateLiteral: cell.format.expectsFoundationDateLiteral
        )

        let witness = try #require(handlerWitnessBlock(witnessName: "onGetItem", in: source))
        let generatedArgument = try #require(
            KawarimiJutsuTestSupport.extractLabeledArgumentExpression(label: "value", from: witness)
        )

        if cell.format.expectsFoundationDateLiteral {
            #expect(generatedArgument.hasPrefix("Date(timeIntervalSince1970:"))
            #expect(generatedArgument.hasSuffix(")"))
        } else {
            #expect(generatedArgument.hasPrefix("\""))
            #expect(generatedArgument.hasSuffix("\""))
            #expect(!generatedArgument.contains("Date(timeIntervalSince1970:"))
        }

        if let exact = cell.exactExpectedArgument {
            #expect(generatedArgument == exact)
        } else {
            // parseable date-time: must not collapse to the epoch-0 fallback.
            #expect(generatedArgument != cell.format.fallbackArgumentExpression)
            #expect(!witness.contains("value: \""))
        }

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
