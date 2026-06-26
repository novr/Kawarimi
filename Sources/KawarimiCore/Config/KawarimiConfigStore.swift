import Foundation
import HTTPTypes

#if canImport(OSLog)
import OSLog
#endif

public enum KawarimiConfigStoreError: Error, Sendable, LocalizedError {
    /// Rejects `..` in the config path to avoid escaping the intended directory.
    case invalidConfigPath(String)
    /// Rejects `..` in the scenarios path to avoid escaping the intended directory.
    case invalidScenariosPath(String)
    case bodyTooLong(actual: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidConfigPath(let path):
            return "Invalid kawarimi config path (must not contain \"..\"): \(path)"
        case .invalidScenariosPath(let path):
            return "Invalid kawarimi scenarios path (must not contain \"..\"): \(path)"
        case .bodyTooLong(let actual, let limit):
            return "Override body exceeds limit (\(actual) UTF-8 bytes, max \(limit))"
        }
    }
}

#if canImport(OSLog)
private let kawarimiConfigStoreLog = Logger(subsystem: "Kawarimi", category: "KawarimiConfigStore")
#endif

private func logInvalidKawarimiConfig(at absolute: String, error: Error) {
    let message = "Ignoring invalid kawarimi config JSON at \(absolute): \(error.localizedDescription)"
#if canImport(OSLog)
    kawarimiConfigStoreLog.warning("\(message, privacy: .public)")
#else
    StandardError.write("KawarimiConfigStore: \(message)")
#endif
}

public enum KawarimiConfigDefaults {
    public static let fileName = "kawarimi.json"
}

public actor KawarimiConfigStore {
    /// Always absolute; relative `file://` URLs can make `Data.write(to:)` fail (e.g. 518).
    private let configPath: String
    private let scenariosPath: String
    private let prefix: String
    private var cachedOverrides: [MockOverride]
    private var cachedScenarios: [KawarimiScenario]
    private var fileWatchers: [KawarimiConfigFileWatcher] = []

    public var pathPrefix: String { prefix }

    public init(
        configPath: String,
        pathPrefix: String = "",
        scenariosPath: String? = nil
    ) throws {
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
        let resolvedScenariosPath = KawarimiScenarioDefaults.resolvedPath(
            explicit: scenariosPath,
            configAbsolutePath: absolute
        )
        let scenarioComponents = (resolvedScenariosPath as NSString).pathComponents
        if scenarioComponents.contains("..") {
            throw KawarimiConfigStoreError.invalidScenariosPath(resolvedScenariosPath)
        }
        self.scenariosPath = Self.absolutePath(from: resolvedScenariosPath)
        self.prefix = KawarimiPath.joinPathPrefix(KawarimiPath.splitPathSegments(pathPrefix))
        let loadedOverrides = Self.loadOverridesFromDisk(at: absolute)
        let loadedScenarios = Self.loadScenariosFromDisk(at: self.scenariosPath)
        Self.logScenarioWarnings(scenarios: loadedScenarios, overrides: loadedOverrides, scenariosPath: self.scenariosPath)
        self.cachedOverrides = loadedOverrides
        self.cachedScenarios = loadedScenarios
    }

    /// Re-reads `kawarimi.json` using the same rules as ``init(configPath:pathPrefix:)``.
    /// Returns ``KawarimiConfigReloadResult/unchanged`` when the decoded overrides match the in-memory cache.
    public func reloadFromDisk() -> KawarimiConfigReloadResult {
        let loaded = Self.loadOverridesFromDisk(at: configPath)
        let loadedScenarios = Self.loadScenariosFromDisk(at: scenariosPath)
        if loaded == cachedOverrides && loadedScenarios == cachedScenarios {
            return .unchanged
        }
        Self.logScenarioWarnings(scenarios: loadedScenarios, overrides: loaded, scenariosPath: scenariosPath)
        cachedOverrides = loaded
        cachedScenarios = loadedScenarios
        return .applied
    }

    /// Watches ``configPath`` and ``scenariosPath`` on disk when ``policy`` is enabled (default: ``KawarimiConfigWatchPolicy/fromEnvironment()``).
    public func startFileWatchIfEnabled(
        policy: KawarimiConfigWatchPolicy = KawarimiConfigWatchPolicy.fromEnvironment()
    ) {
        guard policy.isEnabled, fileWatchers.isEmpty else { return }
        var paths = [configPath]
        if scenariosPath != configPath {
            paths.append(scenariosPath)
        }
        fileWatchers = paths.map { path in
            KawarimiConfigFileWatcher(path: path) { [weak self] in
                guard let self else { return }
                Task { await self.reloadFromDisk() }
            }
        }
    }

    public func stopFileWatch() {
        for watcher in fileWatchers {
            watcher.cancel()
        }
        fileWatchers = []
    }

    private static func loadOverridesFromDisk(at absolute: String) -> [MockOverride] {
        guard let data = FileManager.default.contents(atPath: absolute) else {
            return []
        }
        do {
            let config = try JSONDecoder().decode(KawarimiConfig.self, from: data)
            return config.overrides
        } catch {
            logInvalidKawarimiConfig(at: absolute, error: error)
            return []
        }
    }

    private static func loadScenariosFromDisk(at absolute: String) -> [KawarimiScenario] {
        guard let data = FileManager.default.contents(atPath: absolute) else {
            return []
        }
        do {
            let config = try JSONDecoder().decode(KawarimiScenariosFile.self, from: data)
            return config.scenarios
        } catch {
            logInvalidKawarimiConfig(at: absolute, error: error)
            return []
        }
    }

    public func overrides() -> [MockOverride] {
        cachedOverrides
    }

    public func scenarios() -> [KawarimiScenario] {
        cachedScenarios
    }

    public func configure(_ override: MockOverride) throws {
        let normalized = normalize(override)
        if let body = normalized.body, body.utf8.count > MockOverride.maxBodyLength {
            throw KawarimiConfigStoreError.bodyTooLong(actual: body.utf8.count, limit: MockOverride.maxBodyLength)
        }
        if let index = matchingIndex(for: normalized) {
            var updated = normalized
            if updated.rowId == nil {
                updated.rowId = cachedOverrides[index].rowId
            }
            if updated.rowId == nil {
                updated.rowId = .generate()
            }
            cachedOverrides[index] = updated
        } else {
            var inserted = normalized
            if inserted.rowId == nil {
                inserted.rowId = .generate()
            }
            cachedOverrides.append(inserted)
        }
        try persist()
    }

    /// Drops the first override matching configure identity in this order:
    /// 1) `rowId` exact match,
    /// 2) legacy identity (`path + method + statusCode + exampleId`) only when the incoming row has nil `rowId`.
    /// No-op when nothing matches (idempotent).
    public func removeOverride(_ override: MockOverride) throws {
        let normalized = normalize(override)
        if let index = matchingIndex(for: normalized) {
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
        if let ms = result.delayMs {
            if ms <= 0 {
                result.delayMs = nil
            } else if ms > 60_000 {
                result.delayMs = 60_000
            }
        }
        return result
    }

    private func matchingIndex(for incoming: MockOverride) -> Int? {
        if let rowId = incoming.rowId,
           let rowIdMatch = cachedOverrides.firstIndex(where: {
               $0.rowId == rowId
           }) {
            return rowIdMatch
        }
        guard incoming.rowId == nil else { return nil }
        return cachedOverrides.firstIndex(where: { matchesLegacy($0, incoming) })
    }

    private func matchesLegacy(_ existing: MockOverride, _ new: MockOverride) -> Bool {
        return existing.path == new.path
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

    private static func absolutePath(from path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        if (expanded as NSString).isAbsolutePath {
            return (expanded as NSString).standardizingPath
        }
        let cwd = FileManager.default.currentDirectoryPath
        return (cwd as NSString).appendingPathComponent(expanded)
    }

    private static func logScenarioWarnings(
        scenarios: [KawarimiScenario],
        overrides: [MockOverride],
        scenariosPath: String
    ) {
        KawarimiScenarioValidation.logWarningsIfNeeded(
            scenarios: scenarios,
            overrides: overrides,
            scenariosPath: scenariosPath
        )
    }
}
