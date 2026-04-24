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

/// Must match swift-openapi-generator so `Operations.*` / method names align.
public enum KawarimiNamingStrategy: String, Sendable, CaseIterable, Codable, Equatable {
    case defensive
    case idiomatic
}

/// Must match swift-openapi-generator so handler members can use `Operations.*` types.
public enum KawarimiAccessModifier: String, Sendable, CaseIterable, Codable, Equatable {
    case `public`
    case package
    case `internal`

    var swiftKeyword: String {
        switch self {
        case .public: return "public"
        case .package: return "package"
        case .internal: return "internal"
        }
    }
}

public enum KawarimiHandlerStubPolicy: String, Sendable, CaseIterable, Codable, Equatable {
    case fatalError
    case `throw`
}

public struct KawarimiGeneratorConfigYAML: Equatable, Sendable {
    public var namingStrategy: KawarimiNamingStrategy
    public var accessModifier: KawarimiAccessModifier
    public var handlerStubPolicy: KawarimiHandlerStubPolicy

    public static let defaults = KawarimiGeneratorConfigYAML(
        namingStrategy: .defensive,
        accessModifier: .public,
        handlerStubPolicy: .throw
    )

    public init(
        namingStrategy: KawarimiNamingStrategy = Self.defaults.namingStrategy,
        accessModifier: KawarimiAccessModifier = Self.defaults.accessModifier,
        handlerStubPolicy: KawarimiHandlerStubPolicy = Self.defaults.handlerStubPolicy
    ) {
        self.namingStrategy = namingStrategy
        self.accessModifier = accessModifier
        self.handlerStubPolicy = handlerStubPolicy
    }

    public static func loadBesideOpenAPIYAML(
        atPath openAPIYAMLPath: String,
        targetNameForErrorMessages: String? = nil
    ) throws -> KawarimiGeneratorConfigYAML {
        let dir = URL(fileURLWithPath: openAPIYAMLPath).deletingLastPathComponent()
        let targetName = targetNameForErrorMessages ?? dir.lastPathComponent
        let yamlURL = dir.appendingPathComponent("openapi-generator-config.yaml")
        let ymlURL = dir.appendingPathComponent("openapi-generator-config.yml")
        let existing = [yamlURL, ymlURL].filter { FileManager.default.fileExists(atPath: $0.path) }
        let configURL: URL
        switch existing.count {
        case 0:
            throw KawarimiJutsuError.openapiGeneratorPluginFileLine(
                OpenAPIGeneratorFileErrorMessages.noConfigFileFound(targetName: targetName)
            )
        case 1:
            configURL = existing[0]
        default:
            throw KawarimiJutsuError.openapiGeneratorPluginFileLine(
                OpenAPIGeneratorFileErrorMessages.multipleConfigFiles(targetName: targetName, files: existing)
            )
        }
        guard let data = FileManager.default.contents(atPath: configURL.path),
              let text = String(data: data, encoding: .utf8)
        else {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configURL.path,
                reason: "Could not read file"
            )
        }
        let parsed: OpenAPIGeneratorConfigKawarimiSlice
        do {
            parsed = try YAMLDecoder().decode(OpenAPIGeneratorConfigKawarimiSlice.self, from: text)
        } catch {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configURL.path,
                reason: String(describing: error)
            )
        }
        let naming: KawarimiNamingStrategy
        if let raw = parsed.namingStrategy?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            guard let strategy = KawarimiNamingStrategy(rawValue: raw) else {
                throw KawarimiJutsuError.generatorConfigInvalid(
                    path: configURL.path,
                    reason: "Unsupported namingStrategy: \(raw) (only defensive or idiomatic)"
                )
            }
            naming = strategy
        } else {
            naming = Self.defaults.namingStrategy
        }
        let access: KawarimiAccessModifier
        if let raw = parsed.accessModifier?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            guard let modifier = KawarimiAccessModifier(rawValue: raw) else {
                throw KawarimiJutsuError.generatorConfigInvalid(
                    path: configURL.path,
                    reason: "Unsupported accessModifier: \(raw) (only public, package, or internal)"
                )
            }
            access = modifier
        } else {
            access = Self.defaults.accessModifier
        }
        return KawarimiGeneratorConfigYAML(
            namingStrategy: naming,
            accessModifier: access,
            handlerStubPolicy: Self.defaults.handlerStubPolicy
        )
    }
}

extension KawarimiNamingStrategy {
    public func swiftOperationTypeName(forOperationId operationID: String) throws -> String {
        switch self {
        case .defensive:
            return try DefensiveSafeNameGenerator().swiftTypeName(for: operationID)
        case .idiomatic:
            return try IdiomaticSafeNameGenerator(defensive: DefensiveSafeNameGenerator()).swiftTypeName(for: operationID)
        }
    }

    public func swiftOperationMethodName(forOperationId operationID: String) throws -> String {
        switch self {
        case .defensive:
            return try DefensiveSafeNameGenerator().swiftMemberName(for: operationID)
        case .idiomatic:
            return try IdiomaticSafeNameGenerator(defensive: DefensiveSafeNameGenerator()).swiftMemberName(for: operationID)
        }
    }

    public static func loadBesideOpenAPIYAML(
        atPath openAPIYAMLPath: String,
        targetNameForErrorMessages: String? = nil
    ) throws -> KawarimiNamingStrategy {
        try KawarimiGeneratorConfigYAML.loadBesideOpenAPIYAML(
            atPath: openAPIYAMLPath,
            targetNameForErrorMessages: targetNameForErrorMessages
        ).namingStrategy
    }
}

// MARK: - Config YAML

private struct OpenAPIGeneratorConfigKawarimiSlice: Decodable {
    var namingStrategy: String?
    var accessModifier: String?
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
    func swiftTypeName(for documentedName: String) throws -> String
    func swiftMemberName(for documentedName: String) throws -> String
}

private struct DefensiveSafeNameGenerator: SafeNameGenerator {
    func swiftTypeName(for documentedName: String) throws -> String { swiftName(for: documentedName) }
    func swiftMemberName(for documentedName: String) throws -> String { swiftName(for: documentedName) }

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

private struct IdiomaticSafeNameGenerator: SafeNameGenerator {
    var defensive: DefensiveSafeNameGenerator

    func swiftTypeName(for documentedName: String) throws -> String {
        try swiftName(for: documentedName, capitalize: true)
    }

    func swiftMemberName(for documentedName: String) throws -> String {
        try swiftName(for: documentedName, capitalize: false)
    }

    private func swiftName(for documentedName: String, capitalize: Bool) throws -> String {
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
                throw KawarimiJutsuError.idiomaticNamingInvariantViolated(documentedName: documentedName)
            }
            if case .modifying = state {
                throw KawarimiJutsuError.idiomaticNamingInvariantViolated(documentedName: documentedName)
            }
        }
        let bufferString = String(buffer)
        if capitalize {
            return try defensive.swiftTypeName(for: bufferString)
        }
        return try defensive.swiftMemberName(for: bufferString)
    }

    private static let wordSeparators: Set<Character> = ["_", "-", " ", "/", "+"]
}
