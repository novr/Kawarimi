import Foundation

public actor MockConfigStore {
    private let configPath: String
    private var cachedOverrides: [MockOverride]

    public init(configPath: String) {
        self.configPath = configPath
        if let data = FileManager.default.contents(atPath: configPath),
           let config = try? JSONDecoder().decode(MockConfig.self, from: data) {
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

    /// Path を `/api` プレフィックス付きに正規化する（プラン仕様）。
    private func normalizing(_ override: MockOverride) -> MockOverride {
        var result = override
        if !result.path.hasPrefix("/") {
            result.path = "/" + result.path
        }
        if !result.path.hasPrefix("/api") {
            result.path = "/api" + (result.path == "/" ? "" : result.path)
        }
        result.method = result.method.uppercased()
        return result
    }

    private func matches(_ existing: MockOverride, _ new: MockOverride) -> Bool {
        existing.path == new.path
            && existing.method == new.method
            && existing.mockId == new.mockId
    }

    private func persist() throws {
        let config = MockConfig(overrides: cachedOverrides)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let url = URL(fileURLWithPath: configPath)
        try data.write(to: url)
    }
}
