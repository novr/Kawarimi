import Foundation
import HTTPTypes
import OSLog

public enum KawarimiConfigStoreError: Error, Sendable, LocalizedError {
    /// Rejects `..` in the config path to avoid escaping the intended directory.
    case invalidConfigPath(String)
    case bodyTooLong(actual: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidConfigPath(let path):
            return "Invalid kawarimi config path (must not contain \"..\"): \(path)"
        case .bodyTooLong(let actual, let limit):
            return "Override body exceeds limit (\(actual) UTF-8 bytes, max \(limit))"
        }
    }
}

private let kawarimiConfigStoreLog = Logger(subsystem: "Kawarimi", category: "KawarimiConfigStore")

/// Default relative path / basename for persisted runtime overrides consumed by ``KawarimiConfigStore``.
public enum KawarimiConfigDefaults {
    public static let fileName = "kawarimi.json"
}

public actor KawarimiConfigStore {
    /// Always absolute; relative `file://` URLs can make `Data.write(to:)` fail (e.g. 518).
    private let configPath: String
    private let prefix: String
    private var cachedOverrides: [MockOverride]

    /// Same prefix as middleware / `registerHandlers` for override resolution.
    public var pathPrefix: String { prefix }

    public init(configPath: String, pathPrefix: String = OpenAPIPathPrefix.defaultMountPath) throws {
        let components = (configPath as NSString).pathComponents
        if components.contains("..") {
            throw KawarimiConfigStoreError.invalidConfigPath(configPath)
        }
        let expanded = (configPath as NSString).expandingTildeInPath
        let absolute: String
        if (expanded as NSString).isAbsolutePath {
            absolute = (expanded as NSString).standardizingPath
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            absolute = (cwd as NSString).appendingPathComponent(expanded)
        }
        self.configPath = absolute
        self.prefix = OpenAPIPathPrefix.normalizedPrefix(pathPrefix)
        if let data = FileManager.default.contents(atPath: absolute) {
            do {
                let config = try JSONDecoder().decode(KawarimiConfig.self, from: data)
                self.cachedOverrides = config.overrides
            } catch {
                kawarimiConfigStoreLog.warning(
                    "Ignoring invalid kawarimi config JSON at \(absolute, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                self.cachedOverrides = []
            }
        } else {
            self.cachedOverrides = []
        }
    }

    public func overrides() -> [MockOverride] {
        cachedOverrides
    }

    public func configure(_ override: MockOverride) throws {
        let normalized = normalize(override)
        if let body = normalized.body, body.utf8.count > MockOverride.maxBodyLength {
            throw KawarimiConfigStoreError.bodyTooLong(actual: body.utf8.count, limit: MockOverride.maxBodyLength)
        }
        if let index = cachedOverrides.firstIndex(where: { matches($0, normalized) }) {
            cachedOverrides[index] = normalized
        } else {
            cachedOverrides.append(normalized)
        }
        try persist()
    }

    /// Drops the first override that matches the same identity as ``configure`` (path, method, status, example id).
    /// No-op when nothing matches (idempotent).
    public func removeOverride(_ override: MockOverride) throws {
        let normalized = normalize(override)
        if let index = cachedOverrides.firstIndex(where: { matches($0, normalized) }) {
            cachedOverrides.remove(at: index)
            try persist()
        }
    }

    public func reset() throws {
        cachedOverrides = []
        try persist()
    }

    private func normalize(_ override: MockOverride) -> MockOverride {
        var result = override
        if !result.path.hasPrefix("/") {
            result.path = "/" + result.path
        }
        if !result.path.hasPrefix(prefix) {
            result.path = prefix + (result.path == "/" ? "" : result.path)
        }
        if let m = HTTPRequest.Method(result.method.rawValue.uppercased()) {
            result.method = m
        }
        if result.body?.isEmpty == true {
            result.body = nil
            result.contentType = nil
        }
        if result.contentType?.isEmpty == true {
            result.contentType = nil
        }
        if result.exampleId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.exampleId = nil
        }
        return result
    }

    private func matches(_ existing: MockOverride, _ new: MockOverride) -> Bool {
        existing.path == new.path
            && existing.method == new.method
            && existing.statusCode == new.statusCode
            && normalizedExampleId(existing.exampleId) == normalizedExampleId(new.exampleId)
    }

    private func normalizedExampleId(_ id: String?) -> String? {
        guard let t = id?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    private func persist() throws {
        let config = KawarimiConfig(overrides: cachedOverrides)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let url = URL(fileURLWithPath: configPath, isDirectory: false)
        try data.write(to: url, options: .atomic)
    }
}
