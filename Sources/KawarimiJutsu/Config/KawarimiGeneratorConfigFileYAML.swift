import Foundation
import KawarimiCore
import Yams

public struct KawarimiGeneratorConfigFile: Equatable, Sendable {
    public var handlerStubPolicyRaw: String?
    public var generateKawarimi: Bool
    public var generateHandler: Bool
    public var generateSpec: Bool

    public static let defaults = KawarimiGeneratorConfigFile(
        handlerStubPolicyRaw: nil,
        generateKawarimi: true,
        generateHandler: true,
        generateSpec: true
    )

    public init(
        handlerStubPolicyRaw: String? = nil,
        generateKawarimi: Bool = true,
        generateHandler: Bool = true,
        generateSpec: Bool = true
    ) {
        self.handlerStubPolicyRaw = handlerStubPolicyRaw
        self.generateKawarimi = generateKawarimi
        self.generateHandler = generateHandler
        self.generateSpec = generateSpec
    }

    public func validateAtLeastOneOutputEnabled(configPath: String) throws {
        guard generateKawarimi || generateHandler || generateSpec else {
            throw KawarimiJutsuError.generatorConfigInvalid(
                path: configPath,
                reason: "At least one of generateKawarimi, generateHandler, or generateSpec must be true"
            )
        }
    }

    public static func outputFileNames(for config: KawarimiGeneratorConfigFile) -> [String] {
        var names: [String] = []
        if config.generateKawarimi { names.append("Kawarimi.swift") }
        if config.generateHandler { names.append("KawarimiHandler.swift") }
        if config.generateSpec { names.append("KawarimiSpec.swift") }
        return names
    }
}

public enum KawarimiGeneratorConfigFileYAML {
    public static func loadBesideOpenAPIYAML(
        atPath openAPIYAMLPath: String,
        targetNameForErrorMessages: String? = nil
    ) throws -> KawarimiGeneratorConfigFile? {
        let dir = URL(fileURLWithPath: openAPIYAMLPath).deletingLastPathComponent()
        let targetName = targetNameForErrorMessages ?? dir.lastPathComponent
        let yamlURL = dir.appendingPathComponent("kawarimi-generator-config.yaml")
        let ymlURL = dir.appendingPathComponent("kawarimi-generator-config.yml")
        let existing = [yamlURL, ymlURL].filter { FileManager.default.fileExists(atPath: $0.path) }
        switch existing.count {
        case 0:
            return nil
        case 1:
            break
        default:
            throw KawarimiJutsuError.kawarimiGeneratorConfigDiscovery(
                KawarimiGeneratorConfigSourceMessages.multipleKawarimiGeneratorConfigs(
                    targetName: targetName,
                    files: existing
                )
            )
        }
        let url = existing[0]
        guard let data = FileManager.default.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        struct Slice: Decodable {
            var handlerStubPolicy: String?
            var generateKawarimi: Bool?
            var generateHandler: Bool?
            var generateSpec: Bool?
        }
        do {
            let slice = try YAMLDecoder().decode(Slice.self, from: text)
            let raw = slice.handlerStubPolicy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let policyRaw = raw.isEmpty ? nil : raw
            let file = KawarimiGeneratorConfigFile(
                handlerStubPolicyRaw: policyRaw,
                generateKawarimi: slice.generateKawarimi ?? true,
                generateHandler: slice.generateHandler ?? true,
                generateSpec: slice.generateSpec ?? true
            )
            try file.validateAtLeastOneOutputEnabled(configPath: url.path)
            return file
        } catch let error as KawarimiJutsuError {
            throw error
        } catch {
            let path = url.path
            let msg = String(describing: error).replacingOccurrences(of: "\n", with: " ")
            StandardError.write("Kawarimi warning: invalid kawarimi-generator-config YAML at \(path): \(msg)")
            return nil
        }
    }

    public static func handlerStubPolicyBesideOpenAPIYAML(
        atPath openAPIYAMLPath: String,
        targetNameForErrorMessages: String? = nil
    ) throws -> (path: String, value: String)? {
        let dir = URL(fileURLWithPath: openAPIYAMLPath).deletingLastPathComponent()
        let targetName = targetNameForErrorMessages ?? dir.lastPathComponent
        let yamlURL = dir.appendingPathComponent("kawarimi-generator-config.yaml")
        let ymlURL = dir.appendingPathComponent("kawarimi-generator-config.yml")
        let existing = [yamlURL, ymlURL].filter { FileManager.default.fileExists(atPath: $0.path) }
        switch existing.count {
        case 0:
            return nil
        case 1:
            break
        default:
            throw KawarimiJutsuError.kawarimiGeneratorConfigDiscovery(
                KawarimiGeneratorConfigSourceMessages.multipleKawarimiGeneratorConfigs(
                    targetName: targetName,
                    files: existing
                )
            )
        }
        let url = existing[0]
        guard let file = try loadBesideOpenAPIYAML(
            atPath: openAPIYAMLPath,
            targetNameForErrorMessages: targetNameForErrorMessages
        ), let raw = file.handlerStubPolicyRaw else {
            return nil
        }
        return (url.path, raw)
    }
}
