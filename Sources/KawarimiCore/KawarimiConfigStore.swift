import Foundation

public enum KawarimiConfigStoreError: Error, Sendable {
    /// `..` による設定パスからの脱出を防ぐ。
    case invalidConfigPath(String)
    /// 設定ファイルと転送のメモリ・サイズを抑える。
    case bodyTooLong(actual: Int, limit: Int)
}

public actor KawarimiConfigStore {
    private let configPath: String
    private let storedPathPrefix: String
    private var cachedOverrides: [MockOverride]

    /// ミドルウェア・`registerHandlers` と同一パスでオーバーライドを解決する。
    public var pathPrefix: String { storedPathPrefix }

    public init(configPath: String, pathPrefix: String = "/api") throws {
        let components = (configPath as NSString).pathComponents
        if components.contains("..") {
            throw KawarimiConfigStoreError.invalidConfigPath(configPath)
        }
        self.configPath = configPath
        self.storedPathPrefix = OpenAPIPathPrefix.normalizedPrefix(pathPrefix, defaultIfEmpty: "/api")
        if let data = FileManager.default.contents(atPath: configPath),
           let config = try? JSONDecoder().decode(KawarimiConfig.self, from: data) {
            self.cachedOverrides = config.overrides
        } else {
            self.cachedOverrides = []
        }
    }

    public func overrides() -> [MockOverride] {
        cachedOverrides
    }

    public func configure(_ override: MockOverride) throws {
        let normalized = normalizing(override)
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

    public func reset() throws {
        cachedOverrides = []
        try persist()
    }

    /// インターセプタの `PathTemplate` 一致とパスをそろえる。
    private func normalizing(_ override: MockOverride) -> MockOverride {
        var result = override
        if !result.path.hasPrefix("/") {
            result.path = "/" + result.path
        }
        let prefix = storedPathPrefix
        if !result.path.hasPrefix(prefix) {
            result.path = prefix + (result.path == "/" ? "" : result.path)
        }
        result.method = result.method.uppercased()
        if result.body?.isEmpty == true {
            result.body = nil
            result.contentType = nil
        }
        if result.contentType?.isEmpty == true {
            result.contentType = nil
        }
        return result
    }

    private func matches(_ existing: MockOverride, _ new: MockOverride) -> Bool {
        existing.path == new.path
            && existing.method == new.method
            && existing.mockId == new.mockId
    }

    private func persist() throws {
        let config = KawarimiConfig(overrides: cachedOverrides)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let url = URL(fileURLWithPath: configPath)
        try data.write(to: url)
    }
}
