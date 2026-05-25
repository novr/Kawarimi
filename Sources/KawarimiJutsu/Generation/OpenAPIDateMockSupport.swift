import Foundation
import OpenAPIKit

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

    private struct _KawarimiJSONDateField: Decodable {
        let d: Date
    }

    private static func sanitizeForSourceCommentLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "*/", with: "* /")
    }
}
