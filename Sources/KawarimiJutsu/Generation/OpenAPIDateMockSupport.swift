import Foundation
import OpenAPIKit

struct MockJSONSynthesisContext {
    let operationId: String
    let diagnosticPath: String
    var warnings: [String] = []
}

enum OpenAPIDateMockSupport {
    static func isOpenAPIAbsoluteDateStringSchema(_ schema: JSONSchema) -> Bool {
        guard let tf = schema.jsonTypeFormat else { return false }
        guard case .string(let fmt) = tf else { return false }
        switch fmt {
        case .dateTime, .date: return true
        default: return false
        }
    }

    static func openAPIAbsoluteDateStringIsDateOnly(_ schema: JSONSchema) -> Bool {
        guard let tf = schema.jsonTypeFormat else { return false }
        guard case .string(let fmt) = tf else { return false }
        return fmt == .date
    }

    static func primaryExampleStringValue(_ example: AnyCodable?) -> String? {
        guard let example else { return nil }
        guard let data = try? JSONEncoder().encode(example) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    static func stderrWarningForDateTimeStubFallback(
        operationId: String,
        diagnosticPath: String,
        reason: String
    ) -> String {
        let op = sanitizeForSourceCommentLine(operationId)
        let path = sanitizeForSourceCommentLine(diagnosticPath)
        let r = sanitizeForSourceCommentLine(reason)
        return "Kawarimi warning: KawarimiHandler stub: date-time (or date) field uses epoch 0 (\(r)); operationId \(op); \(path)"
    }

    static func parseOpenAPIDateExample(_ string: String, dateOnly: Bool) -> Date? {
        if !dateOnly {
            if let data = try? JSONSerialization.data(withJSONObject: ["d": string], options: []) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let wrapped = try? decoder.decode(_KawarimiJSONDateField.self, from: data) {
                    return wrapped.d
                }
            }
        }

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let d = isoBasic.date(from: string) { return d }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        if let d = isoFrac.date(from: string) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        if dateOnly {
            df.calendar = Calendar(identifier: .gregorian)
            df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: string) { return d }
            return nil
        }
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        ]
        for pattern in patterns {
            df.dateFormat = pattern
            if let d = df.date(from: string) { return d }
        }
        return nil
    }

    static func swiftDateLiteralForDateSchema(
        resolved: JSONSchema,
        operationId: String,
        diagnosticPath: String,
        handlerStubWarnings: inout [String]
    ) -> String {
        let dateOnly = openAPIAbsoluteDateStringIsDateOnly(resolved)
        let exampleStr = primaryExampleStringValue(resolved.examples.first)
        guard let s = exampleStr?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            handlerStubWarnings.append(
                stderrWarningForDateTimeStubFallback(
                    operationId: operationId,
                    diagnosticPath: diagnosticPath,
                    reason: "no example string"
                )
            )
            return "Date(timeIntervalSince1970: 0)"
        }
        guard let date = parseOpenAPIDateExample(s, dateOnly: dateOnly) else {
            handlerStubWarnings.append(
                stderrWarningForDateTimeStubFallback(
                    operationId: operationId,
                    diagnosticPath: diagnosticPath,
                    reason: "parse failed for example"
                )
            )
            return "Date(timeIntervalSince1970: 0)"
        }
        let interval = date.timeIntervalSince1970
        return "Date(timeIntervalSince1970: \(interval))"
    }

    static func jsonFragmentForDateSchema(
        resolved: JSONSchema,
        synthesisContext: inout MockJSONSynthesisContext,
        fieldPath: String
    ) -> String {
        let dateOnly = openAPIAbsoluteDateStringIsDateOnly(resolved)
        let exampleStr = primaryExampleStringValue(resolved.examples.first)
        let path = fieldPath.isEmpty ? synthesisContext.diagnosticPath : "\(synthesisContext.diagnosticPath) · \(fieldPath)"
        if let s = exampleStr?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            if parseOpenAPIDateExample(s, dateOnly: dateOnly) != nil {
                return jsonEncodedStringFragment(s)
            }
            synthesisContext.warnings.append(
                stderrWarningForDateTimeStubFallback(
                    operationId: synthesisContext.operationId,
                    diagnosticPath: path,
                    reason: "parse failed for example in mock JSON"
                )
            )
        } else {
            synthesisContext.warnings.append(
                stderrWarningForDateTimeStubFallback(
                    operationId: synthesisContext.operationId,
                    diagnosticPath: path,
                    reason: "no example string in mock JSON"
                )
            )
        }
        let fallback = dateOnly ? "1970-01-01" : "1970-01-01T00:00:00Z"
        return jsonEncodedStringFragment(fallback)
    }

    static func generatedStubJSONDecoderMethodSource() -> String {
        """
            private static func _kawarimiStubJSONDecoder() -> JSONDecoder {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let string = try container.decode(String.self)
                    if let data = try? JSONSerialization.data(withJSONObject: ["d": string], options: []) {
                        let inner = JSONDecoder()
                        inner.dateDecodingStrategy = .iso8601
                        if let wrapped = try? inner.decode(_KawarimiStubJSONDateField.self, from: data) {
                            return wrapped.d
                        }
                    }
                    let isoBasic = ISO8601DateFormatter()
                    isoBasic.formatOptions = [.withInternetDateTime, .withTimeZone]
                    if let d = isoBasic.date(from: string) { return d }
                    let isoFrac = ISO8601DateFormatter()
                    isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
                    if let d = isoFrac.date(from: string) { return d }
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.timeZone = TimeZone(secondsFromGMT: 0)
                    df.calendar = Calendar(identifier: .gregorian)
                    df.dateFormat = "yyyy-MM-dd"
                    if let d = df.date(from: string) { return d }
                    let patterns = [
                        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
                        "yyyy-MM-dd'T'HH:mm:ss'Z'",
                        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                    ]
                    for pattern in patterns {
                        df.dateFormat = pattern
                        if let d = df.date(from: string) { return d }
                    }
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Kawarimi stub JSONDecoder: unparseable date string"
                    )
                }
                return decoder
            }

            private struct _KawarimiStubJSONDateField: Decodable {
                let d: Date
            }
        """
    }

    private static func jsonEncodedStringFragment(_ string: String) -> String {
        guard let data = try? JSONEncoder().encode(string),
              let s = String(data: data, encoding: .utf8)
        else {
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return s
    }

    private struct _KawarimiJSONDateField: Decodable {
        let d: Date
    }

    private static func sanitizeForSourceCommentLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "*/", with: "* /")
    }
}
