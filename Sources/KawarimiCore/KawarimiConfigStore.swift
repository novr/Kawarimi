import Foundation

/// Store の初期化・configure で発生しうるエラー。
public enum KawarimiConfigStoreError: Error, Sendable {
    /// configPath に ".." が含まれており path traversal の可能性がある。
    case invalidConfigPath(String)
    /// override.body が MockOverride.maxBodyLength を超えている。
    case bodyTooLong(actual: Int, limit: Int)
}

public actor KawarimiConfigStore {
    private let configPath: String
    /// Path 正規化で付与するプレフィックス（例: "/api"）。デフォルト "/api"。
    private let pathPrefix: String
    private var cachedOverrides: [MockOverride]

    /// - Throws: `KawarimiConfigStoreError.invalidConfigPath` が configPath に ".." を含む場合。
    public init(configPath: String, pathPrefix: String = "/api") throws {
        let components = (configPath as NSString).pathComponents
        if components.contains("..") {
            throw KawarimiConfigStoreError.invalidConfigPath(configPath)
        }
        self.configPath = configPath
        self.pathPrefix = pathPrefix.hasSuffix("/") ? String(pathPrefix.dropLast()) : pathPrefix
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

    /// - Throws: `KawarimiConfigStoreError.bodyTooLong` が body が `MockOverride.maxBodyLength` を超える場合。
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

    /// Path を pathPrefix 付きに正規化する。body/contentType の空文字は nil に正規化する。
    private func normalizing(_ override: MockOverride) -> MockOverride {
        var result = override
        if !result.path.hasPrefix("/") {
            result.path = "/" + result.path
        }
        let prefix = pathPrefix.hasPrefix("/") ? pathPrefix : "/" + pathPrefix
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
