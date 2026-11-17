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
    /// ``Bundle/url(forResource:withExtension:subdirectory:)`` returned nil.
    case resourceNotFound(resource: String, fileExtension: String, subdirectory: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidConfigPath(let path):
            return "Invalid kawarimi config path (must not contain \"..\"): \(path)"
        case .invalidScenariosPath(let path):
            return "Invalid kawarimi scenarios path (must not contain \"..\"): \(path)"
        case .bodyTooLong(let actual, let limit):
            return "Override body exceeds limit (\(actual) UTF-8 bytes, max \(limit))"
        case .resourceNotFound(let resource, let fileExtension, let subdirectory):
            let place = subdirectory.map { " in \($0)" } ?? ""
            return "Kawarimi bundle resource not found: \(resource).\(fileExtension)\(place)"
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

public enum KawarimiConfigPersistence: Sendable, Equatable {
    /// Mutations are written to the config file; reload and file watch read it again.
    case disk
    /// Files are read once at init; mutations stay in memory and are lost when the process exits.
    case memoryOnly
}

public actor KawarimiConfigStore {
    private struct Files: Sendable {
        /// Always absolute; relative `file://` URLs can make `Data.write(to:)` fail (e.g. 518).
        let configPath: String
        let scenariosPath: String
    }

    /// nil when ``persistence`` is ``KawarimiConfigPersistence/memoryOnly``, so no code path can write or re-read.
    private let files: Files?
    private let prefix: String
    private var cachedOverrides: [MockOverride]
    private var cachedScenarios: [KawarimiScenario]
    private var fileWatchers: [KawarimiConfigFileWatcher] = []

    public var pathPrefix: String { prefix }
    public nonisolated let persistence: KawarimiConfigPersistence

    public init(
        configPath: String,
        pathPrefix: String = "",
        scenariosPath: String? = nil
    ) throws {
        try self.init(configPath: configPath, pathPrefix: pathPrefix, scenariosPath: scenariosPath, persistence: .disk)
    }

    /// Starts without files and always uses ``KawarimiConfigPersistence/memoryOnly``.
    /// Seed overrides are normalized like ``configure(_:)`` (path prefix, method, empty fields) so `/greet` matches under `/api`.
    public init(
        pathPrefix: String = "",
        overrides: [MockOverride] = [],
        scenarios: [KawarimiScenario] = []
    ) {
        let prefix = KawarimiPath.joinPathPrefix(KawarimiPath.splitPathSegments(pathPrefix))
        let normalized = overrides.map { Self.normalize($0, prefix: prefix) }
        self.files = nil
        self.persistence = .memoryOnly
        self.prefix = prefix
        Self.logScenarioWarnings(scenarios: scenarios, overrides: normalized, scenariosPath: "(in-memory scenarios)")
        self.cachedOverrides = normalized
        self.cachedScenarios = scenarios
    }

    private init(
        configPath: String,
        pathPrefix: String,
        scenariosPath: String?,
        persistence: KawarimiConfigPersistence
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
        let resolvedScenariosPath = KawarimiScenarioDefaults.resolvedPath(
            explicit: scenariosPath,
            configAbsolutePath: absolute
        )
        let scenarioComponents = (resolvedScenariosPath as NSString).pathComponents
        if scenarioComponents.contains("..") {
            throw KawarimiConfigStoreError.invalidScenariosPath(resolvedScenariosPath)
        }
        let absoluteScenariosPath = Self.absolutePath(from: resolvedScenariosPath)
        self.files = persistence == .disk
            ? Files(configPath: absolute, scenariosPath: absoluteScenariosPath)
            : nil
        self.persistence = persistence
        self.prefix = KawarimiPath.joinPathPrefix(KawarimiPath.splitPathSegments(pathPrefix))
        let loadedOverrides = Self.loadOverridesFromDisk(at: absolute)
        let loadedScenarios = Self.loadScenariosFromDisk(at: absoluteScenariosPath)
        Self.logScenarioWarnings(scenarios: loadedScenarios, overrides: loadedOverrides, scenariosPath: absoluteScenariosPath)
        self.cachedOverrides = loadedOverrides
        self.cachedScenarios = loadedScenarios
    }

    /// Loads from file URLs such as ``Bundle/url(forResource:withExtension:subdirectory:)`` or a Documents copy.
    ///
    /// Prefer this over string paths when the caller already has a `URL` (simulator / device sandbox).
    /// Non-file URLs throw ``KawarimiConfigStoreError/invalidConfigPath`` or ``invalidScenariosPath``.
    /// With ``KawarimiConfigPersistence/disk``, `configure`, `removeOverride`, and `reset` write to `configURL`; an app-bundle URL is not writable, so copy into the container first when mutations must persist.
    /// With ``KawarimiConfigPersistence/memoryOnly``, the files are read once (a bundle URL is fine) and later mutations stay in memory.
    /// When `scenariosURL` is nil, scenario lookup stays ``KawarimiScenarioDefaults/resolvedPath(explicit:configAbsolutePath:environment:)``.
    public init(
        configURL: URL,
        pathPrefix: String = "",
        scenariosURL: URL? = nil,
        persistence: KawarimiConfigPersistence = .disk
    ) throws {
        let configPath = try Self.filePath(
            from: configURL,
            invalid: { KawarimiConfigStoreError.invalidConfigPath($0) }
        )
        let scenariosPath: String?
        if let scenariosURL {
            scenariosPath = try Self.filePath(
                from: scenariosURL,
                invalid: { KawarimiConfigStoreError.invalidScenariosPath($0) }
            )
        } else {
            scenariosPath = nil
        }
        try self.init(
            configPath: configPath,
            pathPrefix: pathPrefix,
            scenariosPath: scenariosPath,
            persistence: persistence
        )
    }

    /// Resolves bundle resources with ``Bundle/url(forResource:withExtension:subdirectory:)``, then ``init(configURL:pathPrefix:scenariosURL:)``.
    ///
    /// When `scenariosResource` is nil, scenario lookup stays beside the config resource (or ``KawarimiScenarioDefaults/environmentKey``).
    public init(
        bundle: Bundle = .main,
        configResource: String,
        configExtension: String = "json",
        subdirectory: String? = nil,
        pathPrefix: String = "",
        scenariosResource: String? = nil,
        scenariosExtension: String = "json",
        persistence: KawarimiConfigPersistence = .disk
    ) throws {
        let configURL = try Self.resourceURL(
            bundle: bundle,
            resource: configResource,
            fileExtension: configExtension,
            subdirectory: subdirectory
        )
        let scenariosURL: URL?
        if let scenariosResource {
            scenariosURL = try Self.resourceURL(
                bundle: bundle,
                resource: scenariosResource,
                fileExtension: scenariosExtension,
                subdirectory: subdirectory
            )
        } else {
            scenariosURL = nil
        }
        try self.init(
            configURL: configURL,
            pathPrefix: pathPrefix,
            scenariosURL: scenariosURL,
            persistence: persistence
        )
    }

    private static func resourceURL(
        bundle: Bundle,
        resource: String,
        fileExtension: String,
        subdirectory: String?
    ) throws -> URL {
        guard let url = bundle.url(forResource: resource, withExtension: fileExtension, subdirectory: subdirectory) else {
            throw KawarimiConfigStoreError.resourceNotFound(
                resource: resource,
                fileExtension: fileExtension,
                subdirectory: subdirectory
            )
        }
        return url
    }

    private static func filePath(
        from url: URL,
        invalid: (String) -> KawarimiConfigStoreError
    ) throws -> String {
        guard url.isFileURL else {
            throw invalid(url.absoluteString)
        }
        return url.standardizedFileURL.path
    }

    /// Re-reads `kawarimi.json` using the same rules as ``init(configPath:pathPrefix:)``.
    /// Returns ``KawarimiConfigReloadResult/unchanged`` when the decoded overrides match the in-memory cache.
    /// With ``KawarimiConfigPersistence/memoryOnly`` this is a no-op returning `.unchanged`, so unsaved edits are kept.
    public func reloadFromDisk() -> KawarimiConfigReloadResult {
        guard let files else { return .unchanged }
        let loaded = Self.loadOverridesFromDisk(at: files.configPath)
        let loadedScenarios = Self.loadScenariosFromDisk(at: files.scenariosPath)
        if loaded == cachedOverrides && loadedScenarios == cachedScenarios {
            return .unchanged
        }
        Self.logScenarioWarnings(scenarios: loadedScenarios, overrides: loaded, scenariosPath: files.scenariosPath)
        cachedOverrides = loaded
        cachedScenarios = loadedScenarios
        return .applied
    }

    /// Watches the config and scenarios files when ``policy`` is enabled (default: ``KawarimiConfigWatchPolicy/fromEnvironment()``).
    /// Never starts with ``KawarimiConfigPersistence/memoryOnly``.
    public func startFileWatchIfEnabled(
        policy: KawarimiConfigWatchPolicy = KawarimiConfigWatchPolicy.fromEnvironment()
    ) {
        guard let files, policy.isEnabled, fileWatchers.isEmpty else { return }
        var paths = [files.configPath]
        if files.scenariosPath != files.configPath {
            paths.append(files.scenariosPath)
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
        Self.normalize(override, prefix: prefix)
    }

    private static func normalize(_ override: MockOverride, prefix: String) -> MockOverride {
        var result = override
        if !result.path.hasPrefix("/") {
            result.path = "/" + result.path
        }
        // Match only on a path-segment boundary so `/apixyz` is not mistaken for being
        // under the prefix `/api`.
        if !prefix.isEmpty, result.path != prefix, !result.path.hasPrefix(prefix + "/") {
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
        guard let files else { return }
        let config = KawarimiConfig(overrides: cachedOverrides)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let url = URL(fileURLWithPath: files.configPath, isDirectory: false)
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
