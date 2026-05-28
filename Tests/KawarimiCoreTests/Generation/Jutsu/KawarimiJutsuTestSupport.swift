import Foundation
import KawarimiJutsu
import OpenAPIKit
import Testing

struct DateTimeDecodePayload: Decodable {
    let updatedAt: Date
}

struct DateTimeNoExamplePayload: Decodable {
    let updatedAt: Date
}

struct DateOnlyNoExamplePayload: Decodable {
    let day: Date
}

enum KawarimiJutsuTestSupport {
    static func fixtureURL(name: String, extension ext: String, subdirectory: String = "Fixtures") -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }

    static func parseJSONObject(_ json: String) throws -> Any {
        let data = Data(json.utf8)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    static func normalizedJSONString(_ json: String) throws -> String {
        let object = try parseJSONObject(json)
        if JSONSerialization.isValidJSONObject(object) {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            guard let normalized = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "KawarimiJutsuTests", code: 1)
            }
            return normalized
        }
        if let string = object as? String {
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        if let bool = object as? Bool {
            return bool ? "true" : "false"
        }
        if let number = object as? NSNumber {
            switch String(cString: number.objCType) {
            case "c", "B":
                return number.boolValue ? "true" : "false"
            default:
                return number.stringValue
            }
        }
        if object is NSNull {
            return "null"
        }
        throw NSError(domain: "KawarimiJutsuTests", code: 2)
    }

    static func expectNormalizedJSONEqual(_ lhs: String, _ rhs: String) throws {
        #expect(try normalizedJSONString(lhs) == normalizedJSONString(rhs))
    }

    static func expectGoldenJSON(operationId: String, actual: String) throws {
        guard let url = fixtureURL(name: operationId, extension: "json", subdirectory: "Fixtures/Golden") else {
            Issue.record("golden fixture not found: \(operationId).json")
            return
        }
        let expected = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        try expectNormalizedJSONEqual(actual.trimmingCharacters(in: .whitespacesAndNewlines), expected)
    }

    static func assertHandlerDecodeStubMatchesSpec(
        witnessName: String,
        operationId: String,
        document: OpenAPI.Document,
        source: String,
        decode: (Data) throws -> Void
    ) throws {
        let handlerJSON = try #require(handlerDecodeStubJSONString(witnessName: witnessName, in: source))
        let spec = KawarimiJutsu.generateKawarimiSpecSource(document: document)
        let specJSON = try #require(mockResponseBodyJSONString(operationId: operationId, in: spec))
        try expectNormalizedJSONEqual(handlerJSON, specJSON)
        try decode(Data(handlerJSON.utf8))
    }

    static func assertHandlerInlineDateStub(
        source: String,
        witnessName: String,
        forbiddenSubstrings: [String] = []
    ) {
        guard let witnessBlock = handlerWitnessBlock(witnessName: witnessName, in: source) else {
            Issue.record("handler witness block not found: \(witnessName)")
            return
        }
        #expect(witnessBlock.contains("Date(timeIntervalSince1970:"))
        #expect(!witnessBlock.contains("_kawarimiStubData = Data(\""))
        for forbidden in forbiddenSubstrings {
            #expect(!witnessBlock.contains(forbidden))
        }
    }
}

/// Accepts any JSON root value for `JSONDecoder` smoke tests.
struct AnyJSON: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { return }
        if (try? c.decode(Bool.self)) != nil { return }
        if (try? c.decode(Int.self)) != nil { return }
        if (try? c.decode(Double.self)) != nil { return }
        if (try? c.decode(String.self)) != nil { return }
        if (try? c.decode([String: AnyJSON].self)) != nil { return }
        if (try? c.decode([AnyJSON].self)) != nil { return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }
}

func assertJSONDecoderAcceptsMockBody(_ json: String) throws {
    let data = Data(json.utf8)
    _ = try JSONDecoder().decode(AnyJSON.self, from: data)
}

/// Extracts `body: "..."` from the first `MockResponse` after the matching `operationId` in generated source.
func mockResponseBodyJSONString(operationId: String, in source: String) -> String? {
    let needle = "operationId: \"\(operationId)\""
    guard let opRange = source.range(of: needle) else { return nil }
    let after = source[opRange.upperBound...]
    guard let bodyLabel = after.range(of: "body: \"") else { return nil }
    return extractSwiftStringLiteral(startingAt: bodyLabel.upperBound, in: after)
}

func transportCaseBlock(operationId: String, in source: String) -> String? {
    let caseLabel = "case \"\(operationId)\":"
    guard let caseRange = source.range(of: caseLabel) else { return nil }
    let afterCase = source[caseRange.upperBound...]
    if let nextCase = afterCase.range(of: "\n                    case \"") {
        return String(afterCase[..<nextCase.lowerBound])
    }
    if let defaultCase = afterCase.range(of: "\n                    default:") {
        return String(afterCase[..<defaultCase.lowerBound])
    }
    return String(afterCase)
}

/// Extracts the JSON string inside `HTTPBody("...")` for the `case "<operationId>":` branch in generated `Kawarimi` transport source.
func transportMockBodyJSONString(operationId: String, in source: String) -> String? {
    guard let block = transportCaseBlock(operationId: operationId, in: source) else { return nil }
    guard let bodyOpen = block.range(of: "HTTPBody(\"") else { return nil }
    return extractSwiftStringLiteral(startingAt: bodyOpen.upperBound, in: block)
}

/// Returns the HTTP status Swift name in the transport case (`ok`, `created`, `noContent`).
func transportResponseStatusSwiftName(operationId: String, in source: String) -> String? {
    guard let block = transportCaseBlock(operationId: operationId, in: source) else { return nil }
    guard let statusOpen = block.range(of: "HTTPResponse(status: .") else { return nil }
    var i = statusOpen.upperBound
    var name = ""
    while i < block.endIndex, block[i] != ")" {
        name.append(block[i])
        i = block.index(after: i)
    }
    return name.isEmpty ? nil : name
}

/// Extracts the generated `Endpoint(...)` block for the given `operationId`.
func endpointBlock(operationId: String, in source: String) -> String? {
    let needle = "operationId: \"\(operationId)\""
    guard let opRange = source.range(of: needle) else { return nil }
    let before = source[..<opRange.lowerBound]
    guard let endpointStart = before.range(of: "Endpoint(", options: .backwards) else { return nil }
    let after = source[endpointStart.lowerBound...]
    if let next = after.dropFirst("Endpoint(".count).range(of: "\n                    Endpoint(") {
        return String(after[..<next.lowerBound])
    }
    if let close = after.range(of: "\n                    ),") {
        return String(after[..<close.upperBound])
    }
    return String(after)
}

/// Extracts the JSON string inside `_kawarimiStubData = Data("...")` for the given handler witness (`on…`).
func handlerDecodeStubJSONString(witnessName: String, in source: String) -> String? {
    guard let after = handlerWitnessBlock(witnessName: witnessName, in: source) else { return nil }
    guard let dataLabel = after.range(of: "_kawarimiStubData = Data(\"") else { return nil }
    return extractSwiftStringLiteral(startingAt: dataLabel.upperBound, in: after[...])
}

/// Extracts the generated witness closure block for `var on...` in `KawarimiHandler`.
func handlerWitnessBlock(witnessName: String, in source: String) -> String? {
    let needle = "var \(witnessName):"
    guard let witnessRange = source.range(of: needle) else { return nil }
    let afterWitness = source[witnessRange.lowerBound...]
    if let nextWitness = afterWitness.dropFirst(needle.count).range(of: "\n    var on") {
        return String(afterWitness[..<nextWitness.lowerBound])
    }
    return String(afterWitness)
}

private func extractSwiftStringLiteral<S: StringProtocol>(startingAt start: S.Index, in text: S) -> String? {
    var i = start
    var result = ""
    var escaped = false
    while i < text.endIndex {
        let ch = text[i]
        if escaped {
            switch ch {
            case "\"": result.append("\"")
            case "\\": result.append("\\")
            case "n": result.append("\n")
            case "r": result.append("\r")
            case "t": result.append("\t")
            default: result.append(ch)
            }
            escaped = false
        } else if ch == "\\" {
            escaped = true
        } else if ch == "\"" {
            break
        } else {
            result.append(ch)
        }
        i = text.index(after: i)
    }
    return result.isEmpty ? nil : result
}
