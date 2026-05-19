import Foundation

public enum KawarimiGeneratorConfigLineParser {
    public static func parseBoolFlag(in text: String, key: String) -> Bool? {
        let prefix = key + ":"
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard trimmed.hasPrefix(prefix) else { continue }
            let value = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            switch value.lowercased() {
            case "true": return true
            case "false": return false
            default: return nil
            }
        }
        return nil
    }

    public static func parseOutputOptions(
        from text: String,
        defaultValues: KawarimiGeneratorOutputOptions = .defaults
    ) -> KawarimiGeneratorOutputOptions {
        KawarimiGeneratorOutputOptions(
            generateKawarimi: parseBoolFlag(in: text, key: "generateKawarimi") ?? defaultValues.generateKawarimi,
            generateHandler: parseBoolFlag(in: text, key: "generateHandler") ?? defaultValues.generateHandler,
            generateSpec: parseBoolFlag(in: text, key: "generateSpec") ?? defaultValues.generateSpec
        )
    }

    public static func load(kawarimiConfigURL: URL?) throws -> KawarimiGeneratorOutputOptions {
        guard let configURL = kawarimiConfigURL else { return .defaults }
        guard let data = FileManager.default.contents(atPath: configURL.path),
              let text = String(data: data, encoding: .utf8)
        else {
            return .defaults
        }
        let options = parseOutputOptions(from: text)
        guard options.hasAtLeastOneOutputEnabled else {
            throw KawarimiGeneratorConfigLineParserError.allOutputsDisabled(
                message: KawarimiGeneratorOutputOptions.atLeastOneOutputRequiredMessage(configPath: configURL.path)
            )
        }
        return options
    }
}

public enum KawarimiGeneratorConfigLineParserError: Error, Equatable, Sendable {
    case allOutputsDisabled(message: String)
}
