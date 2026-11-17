import Foundation
import HTTPTypes
import Testing

@testable import KawarimiCore

private func makeSeedDirectory(overrides: [MockOverride]) throws -> (dir: URL, configURL: URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let configURL = dir.appendingPathComponent("kawarimi.json")
    try JSONEncoder().encode(KawarimiConfig(overrides: overrides)).write(to: configURL, options: .atomic)
    return (dir, configURL)
}

private func decodedOverrides(at url: URL) throws -> [MockOverride] {
    try JSONDecoder().decode(KawarimiConfig.self, from: Data(contentsOf: url)).overrides
}

private let seedOverride = MockOverride(
    path: "/api/greet",
    method: .get,
    statusCode: 200,
    body: "{\"seed\":true}",
    contentType: "application/json"
)

@Suite("KawarimiConfigStore memoryOnly", .timeLimit(.minutes(1)))
struct KawarimiConfigStoreMemoryOnlyTests {
    @Test func defaultPersistenceIsDisk() throws {
        let (dir, configURL) = try makeSeedDirectory(overrides: [])
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(try KawarimiConfigStore(configURL: configURL).persistence == .disk)
        #expect(try KawarimiConfigStore(configPath: configURL.path).persistence == .disk)
    }

    @Test func seedsFromURLAndKeepsMutationsOutOfTheFile() async throws {
        let (dir, configURL) = try makeSeedDirectory(overrides: [seedOverride])
        defer { try? FileManager.default.removeItem(at: dir) }
        let before = try Data(contentsOf: configURL)
        let store = try KawarimiConfigStore(configURL: configURL, pathPrefix: "/api", persistence: .memoryOnly)
        #expect(store.persistence == .memoryOnly)
        #expect(await store.overrides().map(\.body) == ["{\"seed\":true}"])

        try await store.configure(MockOverride(path: "/greet", method: .get, statusCode: 500, body: "{\"edited\":true}"))
        #expect(await store.overrides().map(\.statusCode) == [200, 500])
        #expect(await store.overrides().last?.path == "/api/greet")
        try await store.removeOverride(await store.overrides()[0])
        #expect(await store.overrides().map(\.statusCode) == [500])
        try await store.reset()
        #expect(await store.overrides().map(\.body) == ["{\"seed\":true}"])

        #expect(try Data(contentsOf: configURL) == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["kawarimi.json"])
    }

    @Test func bundleResourceSeedAcceptsMutations() async throws {
        let store = try KawarimiConfigStore(
            bundle: .module,
            configResource: "kawarimi",
            subdirectory: "Fixtures/BundleStore",
            pathPrefix: "/api",
            scenariosResource: "kawarimi-scenarios",
            persistence: .memoryOnly
        )
        let configURL = try #require(
            Bundle.module.url(forResource: "kawarimi", withExtension: "json", subdirectory: "Fixtures/BundleStore")
        )
        let before = try decodedOverrides(at: configURL)
        try await store.configure(MockOverride(path: "/api/greet", method: .get, statusCode: 404))
        #expect(await store.overrides().count == 2)
        #expect(await store.scenarios().map(\.scenarioId) == ["login"])
        #expect(try decodedOverrides(at: configURL) == before)
    }

    @Test func reloadFromDiskKeepsUnsavedEdits() async throws {
        let (dir, configURL) = try makeSeedDirectory(overrides: [seedOverride])
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try KawarimiConfigStore(configURL: configURL, pathPrefix: "/api", persistence: .memoryOnly)
        try await store.configure(MockOverride(path: "/api/greet", method: .get, statusCode: 503))
        let expected = await store.overrides()

        try JSONEncoder().encode(KawarimiConfig(overrides: [])).write(to: configURL, options: .atomic)
        #expect(await store.reloadFromDisk() == .unchanged)
        #expect(await store.overrides() == expected)
    }

    @Test func fileWatchDoesNotStart() async throws {
        let (dir, configURL) = try makeSeedDirectory(overrides: [seedOverride])
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try KawarimiConfigStore(configURL: configURL, pathPrefix: "/api", persistence: .memoryOnly)
        await store.startFileWatchIfEnabled(policy: .enabled)

        try JSONEncoder().encode(KawarimiConfig(overrides: [])).write(to: configURL, options: .atomic)
        try await Task.sleep(for: .milliseconds(300))
        #expect(await store.overrides().map(\.body) == ["{\"seed\":true}"])
        await store.stopFileWatch()
    }

    @Test func memoryOnlyResetRereadsConfigFileWithoutWriting() async throws {
        let (dir, configURL) = try makeSeedDirectory(overrides: [seedOverride])
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try KawarimiConfigStore(configURL: configURL, pathPrefix: "/api", persistence: .memoryOnly)
        try await store.configure(MockOverride(path: "/api/greet", method: .get, statusCode: 500, body: "{\"edited\":true}"))

        let replacement = MockOverride(
            path: "/api/other",
            method: .post,
            statusCode: 201,
            body: "{\"from\":\"file\"}",
            contentType: "application/json"
        )
        let replacementData = try JSONEncoder().encode(KawarimiConfig(overrides: [replacement]))
        try replacementData.write(to: configURL, options: .atomic)

        try await store.reset()
        let overrides = await store.overrides()
        #expect(overrides.map(\.path) == ["/api/other"])
        #expect(overrides.map(\.method) == [.post])
        #expect(overrides.map(\.statusCode) == [201])
        #expect(overrides.map(\.body) == ["{\"from\":\"file\"}"])
        #expect(try Data(contentsOf: configURL) == replacementData)
    }

    @Test func memoryOnlyThrowsWhenConfigFileIsMissing() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("kawarimi.json")
        expectStoreError(.configNotFound(missing.path)) {
            _ = try KawarimiConfigStore(configURL: missing, persistence: .memoryOnly)
        }
    }

    @Test func memoryOnlyThrowsWhenConfigJSONIsInvalid() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let configURL = dir.appendingPathComponent("kawarimi.json")
        try Data("not-json".utf8).write(to: configURL)

        expectStoreError(.invalidConfigJSON(path: configURL.path, reason: "")) {
            _ = try KawarimiConfigStore(configURL: configURL, persistence: .memoryOnly)
        }
    }

    @Test func memoryOnlyAcceptsAnEmptyOverrideFileWithoutScenarios() async throws {
        let (dir, configURL) = try makeSeedDirectory(overrides: [])
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try KawarimiConfigStore(configURL: configURL, persistence: .memoryOnly)
        #expect(await store.overrides().isEmpty)
        #expect(await store.scenarios().isEmpty)
    }

    @Test func diskInitStartsEmptyWhenConfigIsMissingOrInvalid() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("kawarimi.json")
        let missingStore = try KawarimiConfigStore(configURL: missing)
        #expect(await missingStore.overrides().isEmpty)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let configURL = dir.appendingPathComponent("kawarimi.json")
        try Data("not-json".utf8).write(to: configURL)
        let invalidStore = try KawarimiConfigStore(configURL: configURL)
        #expect(await invalidStore.overrides().isEmpty)
    }
}

private func expectStoreError(
    _ expected: KawarimiConfigStoreError,
    _ body: () throws -> Void
) {
    do {
        try body()
        Issue.record("expected \(expected)")
    } catch let error as KawarimiConfigStoreError {
        switch (error, expected) {
        case (.configNotFound, .configNotFound), (.invalidConfigJSON, .invalidConfigJSON):
            break
        default:
            Issue.record("expected \(expected), got \(error)")
        }
    } catch {
        Issue.record("expected \(expected), got \(error)")
    }
}
