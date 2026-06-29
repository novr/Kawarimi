import Foundation

public struct KawarimiGeneratorOutputOptions: Equatable, Sendable {
    public var generateKawarimi: Bool
    public var generateHandler: Bool
    public var generateSpec: Bool

    public static let defaults = KawarimiGeneratorOutputOptions(
        generateKawarimi: true,
        generateHandler: true,
        generateSpec: true
    )

    public init(
        generateKawarimi: Bool = true,
        generateHandler: Bool = true,
        generateSpec: Bool = true
    ) {
        self.generateKawarimi = generateKawarimi
        self.generateHandler = generateHandler
        self.generateSpec = generateSpec
    }

    public var hasAtLeastOneOutputEnabled: Bool {
        generateKawarimi || generateHandler || generateSpec
    }

    public var outputFileNames: [String] {
        var names: [String] = []
        if generateKawarimi { names.append("Kawarimi.swift") }
        if generateHandler { names.append("KawarimiHandler.swift") }
        if generateSpec { names.append("KawarimiSpec.swift") }
        return names
    }

    public static func atLeastOneOutputRequiredMessage(configPath: String) -> String {
        "kawarimi-generator-config at \(configPath): at least one of generateKawarimi, generateHandler, or generateSpec must be true"
    }
}
