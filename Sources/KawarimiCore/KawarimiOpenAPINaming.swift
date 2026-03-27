//===----------------------------------------------------------------------===//
//
// Naming logic is adapted from Swift OpenAPI Generator (Apache-2.0) so that
// Kawarimi references Operations.* consistently with swift-openapi-generator.
// See: https://github.com/apple/swift-openapi-generator
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Yams

/// Mirrors `swift-openapi-generator`’s `namingStrategy` values (1.10.x).
public enum KawarimiNamingStrategy: String, Sendable, CaseIterable, Codable, Equatable {
    /// Default for `swift-openapi-generator` when `namingStrategy` is omitted.
    case defensive
    case idiomatic
}

extension KawarimiNamingStrategy {
    /// Swift type name for `Operations.<Name>` (nested operation namespace).
    public func swiftOperationTypeName(forOperationId operationID: String) -> String {
        switch self {
        case .defensive: DefensiveSafeNameGenerator().swiftTypeName(for: operationID)
        case .idiomatic: IdiomaticSafeNameGenerator(defensive: DefensiveSafeNameGenerator()).swiftTypeName(for: operationID)
        }
    }

    /// Swift method name for `APIProtocol` / `KawarimiHandler` methods.
    public func swiftOperationMethodName(forOperationId operationID: String) -> String {
        switch self {
        case .defensive: DefensiveSafeNameGenerator().swiftMemberName(for: operationID)
        case .idiomatic: IdiomaticSafeNameGenerator(defensive: DefensiveSafeNameGenerator()).swiftMemberName(for: operationID)
        }
    }

    /// Reads only `namingStrategy` from `openapi-generator-config.yaml` or `.yml` next to the OpenAPI file.
    /// If no config file exists, or the key is omitted, returns `.defensive` (generator default).
    public static func loadBesideOpenAPIYAML(atPath openAPIYAMLPath: String) throws -> KawarimiNamingStrategy {
        let dir = URL(fileURLWithPath: openAPIYAMLPath).deletingLastPathComponent()
        let candidates = [
            dir.appendingPathComponent("openapi-generator-config.yaml"),
            dir.appendingPathComponent("openapi-generator-config.yml"),
        ]
        guard let configURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return .defensive
        }
        guard let data = FileManager.default.contents(atPath: configURL.path),
              let text = String(data: data, encoding: .utf8)
        else {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configURL.path,
                reason: "ファイルを読み込めませんでした"
            )
        }
        let parsed: OpenAPIGeneratorConfigNamingSlice
        do {
            parsed = try YAMLDecoder().decode(OpenAPIGeneratorConfigNamingSlice.self, from: text)
        } catch {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configURL.path,
                reason: String(describing: error)
            )
        }
        guard let raw = parsed.namingStrategy?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .defensive
        }
        guard let strategy = KawarimiNamingStrategy(rawValue: raw) else {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configURL.path,
                reason: "未対応の namingStrategy: \(raw)（defensive または idiomatic のみ）"
            )
        }
        return strategy
    }
}

// MARK: - Config YAML (Kawarimi reads `namingStrategy` only; other keys are ignored)

private struct OpenAPIGeneratorConfigNamingSlice: Decodable {
    var namingStrategy: String?
}

// MARK: - String helpers (from Swift OpenAPI Generator)

private extension String {
    var uppercasingFirstLetter: String { transformingFirstLetter { $0.uppercased() } }
    var lowercasingFirstLetter: String { transformingFirstLetter { $0.lowercased() } }

    func transformingFirstLetter<T>(_ transformation: (Character) -> T) -> String where T: StringProtocol {
        guard let firstLetterIndex = firstIndex(where: \.isLetter) else { return self }
        return replacingCharacters(
            in: firstLetterIndex..<index(after: firstLetterIndex),
            with: transformation(self[firstLetterIndex])
        )
    }
}

// MARK: - Safe name generators (from Swift OpenAPI Generator)

private protocol SafeNameGenerator {
    func swiftTypeName(for documentedName: String) -> String
    func swiftMemberName(for documentedName: String) -> String
}

/// SOAR-0001-style defensive naming.
private struct DefensiveSafeNameGenerator: SafeNameGenerator {
    func swiftTypeName(for documentedName: String) -> String { swiftName(for: documentedName) }
    func swiftMemberName(for documentedName: String) -> String { swiftName(for: documentedName) }

    private func swiftName(for documentedName: String) -> String {
        guard !documentedName.isEmpty else { return "_empty" }

        let firstCharSet: CharacterSet = .letters.union(.init(charactersIn: "_"))
        let numbers: CharacterSet = .decimalDigits
        let otherCharSet: CharacterSet = .alphanumerics.union(.init(charactersIn: "_"))

        var sanitizedScalars: [Unicode.Scalar] = []
        for (index, scalar) in documentedName.unicodeScalars.enumerated() {
            let allowedSet = index == 0 ? firstCharSet : otherCharSet
            let outScalar: Unicode.Scalar
            if allowedSet.contains(scalar) {
                outScalar = scalar
            } else if index == 0, numbers.contains(scalar) {
                sanitizedScalars.append("_")
                outScalar = scalar
            } else {
                sanitizedScalars.append("_")
                if let entityName = Self.specialCharsMap[scalar] {
                    for char in entityName.unicodeScalars { sanitizedScalars.append(char) }
                } else {
                    sanitizedScalars.append("x")
                    let hexString = String(scalar.value, radix: 16, uppercase: true)
                    for char in hexString.unicodeScalars { sanitizedScalars.append(char) }
                }
                sanitizedScalars.append("_")
                continue
            }
            sanitizedScalars.append(outScalar)
        }

        let validString = String(String.UnicodeScalarView(sanitizedScalars))
        if validString == "_" { return "_underscore_" }
        guard Self.keywords.contains(validString) else { return validString }
        return "_\(validString)"
    }

    private static let keywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "func", "import", "init", "inout", "let", "operator",
        "precedencegroup", "protocol", "struct", "subscript", "typealias", "var", "fileprivate", "internal", "private",
        "public", "static", "defer", "if", "guard", "do", "repeat", "else", "for", "in", "while", "return", "break",
        "continue", "fallthrough", "switch", "case", "default", "where", "catch", "throw", "as", "Any", "false", "is",
        "nil", "rethrows", "super", "self", "Self", "true", "try", "throws", "yield", "String", "Error", "Int", "Bool",
        "Array", "Type", "type", "Protocol", "await",
    ]

    private static let specialCharsMap: [Unicode.Scalar: String] = [
        " ": "space", "!": "excl", "\"": "quot", "#": "num", "$": "dollar", "%": "percnt", "&": "amp", "'": "apos",
        "(": "lpar", ")": "rpar", "*": "ast", "+": "plus", ",": "comma", "-": "hyphen", ".": "period", "/": "sol",
        ":": "colon", ";": "semi", "<": "lt", "=": "equals", ">": "gt", "?": "quest", "@": "commat", "[": "lbrack",
        "\\": "bsol", "]": "rbrack", "^": "hat", "`": "grave", "{": "lcub", "|": "verbar", "}": "rcub", "~": "tilde",
    ]
}

/// SOAR-0013-style idiomatic naming (falls back to defensive).
private struct IdiomaticSafeNameGenerator: SafeNameGenerator {
    var defensive: DefensiveSafeNameGenerator

    func swiftTypeName(for documentedName: String) -> String { swiftName(for: documentedName, capitalize: true) }
    func swiftMemberName(for documentedName: String) -> String { swiftName(for: documentedName, capitalize: false) }

    private func swiftName(for documentedName: String, capitalize: Bool) -> String {
        if documentedName.isEmpty { return capitalize ? "_Empty_" : "_empty_" }

        let isAllUppercase = documentedName.allSatisfy { !$0.isLowercase }

        var buffer: [Character] = []
        buffer.reserveCapacity(documentedName.count)
        enum State: Equatable {
            case modifying
            case preFirstWord
            struct AccumulatingFirstWordContext: Equatable { var isAccumulatingInitialUppercase: Bool }
            case accumulatingFirstWord(AccumulatingFirstWordContext)
            case accumulatingWord
            case waitingForWordStarter
        }
        var state: State = .preFirstWord
        for index in documentedName.indices {
            let char = documentedName[index]
            let previousState = state
            state = .modifying
            switch previousState {
            case .preFirstWord:
                if char == "_" {
                    buffer.append(char)
                    state = .preFirstWord
                } else if char.isNumber {
                    buffer.append(char)
                    state = .accumulatingFirstWord(.init(isAccumulatingInitialUppercase: false))
                } else if char.isLetter {
                    buffer.append(contentsOf: capitalize ? char.uppercased() : char.lowercased())
                    state = .accumulatingFirstWord(
                        .init(isAccumulatingInitialUppercase: !capitalize && char.isUppercase)
                    )
                } else {
                    state = .accumulatingFirstWord(.init(isAccumulatingInitialUppercase: false))
                    buffer.append(char)
                }
            case .accumulatingFirstWord(var context):
                if char.isLetter || char.isNumber {
                    if isAllUppercase {
                        buffer.append(contentsOf: char.lowercased())
                    } else if context.isAccumulatingInitialUppercase {
                        if char.isLowercase {
                            buffer.append(char)
                            context.isAccumulatingInitialUppercase = false
                        } else {
                            let suffix = documentedName.suffix(from: documentedName.index(after: index))
                            if suffix.count >= 2 {
                                let next = suffix.first!
                                let secondNext = suffix.dropFirst().first!
                                if next.isUppercase, secondNext.isLowercase {
                                    context.isAccumulatingInitialUppercase = false
                                    buffer.append(contentsOf: char.lowercased())
                                } else if Self.wordSeparators.contains(next) {
                                    context.isAccumulatingInitialUppercase = false
                                    buffer.append(contentsOf: char.lowercased())
                                } else if next.isUppercase {
                                    buffer.append(contentsOf: char.lowercased())
                                } else {
                                    context.isAccumulatingInitialUppercase = false
                                    buffer.append(char)
                                }
                            } else {
                                buffer.append(contentsOf: char.lowercased())
                                context.isAccumulatingInitialUppercase = false
                            }
                        }
                    } else {
                        buffer.append(char)
                    }
                    state = .accumulatingFirstWord(context)
                } else if ["_", "-", " ", "/", "+"].contains(char) {
                    state = .waitingForWordStarter
                } else if char == "." {
                    buffer.append("_")
                    state = .accumulatingFirstWord(.init(isAccumulatingInitialUppercase: false))
                } else if ["{", "}"].contains(char) {
                    state = .accumulatingFirstWord(.init(isAccumulatingInitialUppercase: false))
                } else {
                    state = .accumulatingFirstWord(.init(isAccumulatingInitialUppercase: false))
                    buffer.append(char)
                }
            case .accumulatingWord:
                if char.isLetter || char.isNumber {
                    if isAllUppercase { buffer.append(contentsOf: char.lowercased()) } else { buffer.append(char) }
                    state = .accumulatingWord
                } else if Self.wordSeparators.contains(char) {
                    state = .waitingForWordStarter
                } else if char == "." {
                    buffer.append("_")
                    state = .accumulatingWord
                } else if ["{", "}"].contains(char) {
                    state = .accumulatingWord
                } else {
                    state = .accumulatingWord
                    buffer.append(char)
                }
            case .waitingForWordStarter:
                if ["_", "-", ".", "/", "+", "{", "}"].contains(char) {
                    state = .waitingForWordStarter
                } else if char.isLetter || char.isNumber {
                    buffer.append(contentsOf: char.uppercased())
                    state = .accumulatingWord
                } else {
                    state = .waitingForWordStarter
                    buffer.append(char)
                }
            case .modifying:
                preconditionFailure("Logic error in idiomatic swiftName, string: '\(documentedName)'")
            }
            precondition(state != .modifying, "Logic error in idiomatic swiftName, string: '\(documentedName)'")
        }
        let defensiveFallback: (String) -> String
        if capitalize {
            defensiveFallback = defensive.swiftTypeName
        } else {
            defensiveFallback = defensive.swiftMemberName
        }
        return defensiveFallback(String(buffer))
    }

    private static let wordSeparators: Set<Character> = ["_", "-", " ", "/", "+"]
}
