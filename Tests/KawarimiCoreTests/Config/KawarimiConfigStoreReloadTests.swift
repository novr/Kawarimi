import Foundation
import KawarimiCore
import Testing

@Suite("KawarimiConfigStore reload", .timeLimit(.minutes(1)))
struct KawarimiConfigStoreReloadTests {
    private func tempConfigURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    private func writeConfig(at url: URL, overrides: [MockOverride]) throws {
        let data = try JSONEncoder().encode(KawarimiConfig(overrides: overrides))
        try data.write(to: url, options: .atomic)
    }

    @Test(.timeLimit(.minutes(1))) func reloadFromDisk_appliesExternalEdit() async throws {
        let url = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try KawarimiConfigStore(configPath: url.path)
        let onDisk = [
            MockOverride(
                path: "/pets",
                method: .get,
                statusCode: 200,
                body: "{\"from\":\"disk\"}",
                contentType: "application/json"
            ),
        ]
        try writeConfig(at: url, overrides: onDisk)
        let result = await store.reloadFromDisk()
        #expect(result == .applied)
        #expect(await store.overrides() == onDisk)
    }

    @Test(.timeLimit(.minutes(1))) func reloadFromDisk_unchanged_afterPersist() async throws {
        let url = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try KawarimiConfigStore(configPath: url.path)
        let override = MockOverride(
            path: "/pets",
            method: .get,
            statusCode: 200,
            body: "{\"persisted\":true}",
            contentType: "application/json"
        )
        try await store.configure(override)
        let result = await store.reloadFromDisk()
        #expect(result == .unchanged)
        #expect(await store.overrides().count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func reloadFromDisk_lastWriteWins_configureAfterReload() async throws {
        let url = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try KawarimiConfigStore(configPath: url.path)
        try writeConfig(
            at: url,
            overrides: [
                MockOverride(path: "/a", method: .get, statusCode: 200, body: "{}", contentType: "application/json"),
            ]
        )
        _ = await store.reloadFromDisk()
        let viaAPI = MockOverride(
            path: "/b",
            method: .post,
            statusCode: 201,
            body: "{\"api\":true}",
            contentType: "application/json"
        )
        try await store.configure(viaAPI)
        let overrides = await store.overrides()
        #expect(overrides.contains { $0.path.hasSuffix("/b") || $0.path == "/b" })
    }

    @Test(.timeLimit(.minutes(1))) func reloadFromDisk_lastWriteWins_reloadAfterConfigure() async throws {
        let url = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try KawarimiConfigStore(configPath: url.path)
        try await store.configure(
            MockOverride(
                path: "/pets",
                method: .get,
                statusCode: 200,
                body: "{\"api\":true}",
                contentType: "application/json"
            )
        )
        let fromDisk = [
            MockOverride(
                path: "/pets",
                method: .get,
                statusCode: 200,
                body: "{\"disk\":true}",
                contentType: "application/json"
            ),
        ]
        try writeConfig(at: url, overrides: fromDisk)
        let result = await store.reloadFromDisk()
        #expect(result == .applied)
        #expect(await store.overrides() == fromDisk)
    }

    @Test(.timeLimit(.minutes(1))) func reloadFromDisk_invalidJSON_clearsToEmpty() async throws {
        let url = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try KawarimiConfigStore(configPath: url.path)
        try await store.configure(
            MockOverride(path: "/x", method: .get, statusCode: 200, body: "{}", contentType: "application/json")
        )
        try "not json".write(to: url, atomically: true, encoding: .utf8)
        let result = await store.reloadFromDisk()
        #expect(result == .applied)
        #expect(await store.overrides().isEmpty)
    }

    @Test(.timeLimit(.minutes(1))) func reloadFromDisk_invalidJSON_unchangedWhenAlreadyEmpty() async throws {
        let url = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try KawarimiConfigStore(configPath: url.path)
        #expect(await store.overrides().isEmpty)
        try "not json".write(to: url, atomically: true, encoding: .utf8)
        let result = await store.reloadFromDisk()
        #expect(result == .unchanged)
        #expect(await store.overrides().isEmpty)
    }

    @Test(.timeLimit(.minutes(1))) func reloadFromDisk_missingFile_clearsOverrides() async throws {
        let url = tempConfigURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try KawarimiConfigStore(configPath: url.path)
        try await store.configure(
            MockOverride(path: "/pets", method: .get, statusCode: 200, body: "{}", contentType: "application/json")
        )
        try FileManager.default.removeItem(at: url)
        let result = await store.reloadFromDisk()
        #expect(result == .applied)
        #expect(await store.overrides().isEmpty)
    }

}
