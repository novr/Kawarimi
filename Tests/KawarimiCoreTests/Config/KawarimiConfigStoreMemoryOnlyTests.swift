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
        #expect(await store.overrides().isEmpty)

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
        defer { Task { await store.stopFileWatch() } }

        try JSONEncoder().encode(KawarimiConfig(overrides: [])).write(to: configURL, options: .atomic)
        try await Task.sleep(for: .milliseconds(300))
        #expect(await store.overrides().map(\.body) == ["{\"seed\":true}"])
    }

    @Test func fileLessStoreStartsFromSeedValues() async throws {
        let empty = KawarimiConfigStore()
        #expect(empty.persistence == .memoryOnly)
        #expect(await empty.overrides().isEmpty)
        #expect(await empty.scenarios().isEmpty)
        #expect(await empty.reloadFromDisk() == .unchanged)

        let seeded = KawarimiConfigStore(pathPrefix: "/api", overrides: [seedOverride])
        #expect(await seeded.pathPrefix == "/api")
        try await seeded.configure(MockOverride(path: "/greet", method: .post, statusCode: 201))
        #expect(await seeded.overrides().map(\.path) == ["/api/greet", "/api/greet"])
        #expect(await seeded.overrides().map(\.method) == [.get, .post])
    }
}
