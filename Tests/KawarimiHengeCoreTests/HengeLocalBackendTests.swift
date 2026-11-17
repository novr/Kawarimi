import Foundation
import KawarimiCore
import Testing

@testable import KawarimiHengeCore

private func makeMemoryStore(pathPrefix: String = "/api") throws -> (KawarimiConfigStore, URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let configURL = dir.appendingPathComponent("kawarimi.json")
    try JSONEncoder().encode(KawarimiConfig(overrides: [])).write(to: configURL)
    let store = try KawarimiConfigStore(configURL: configURL, pathPrefix: pathPrefix, persistence: .memoryOnly)
    return (store, dir)
}

private func makeSpec() throws -> HengeSpecSnapshot {
    let json = """
    {
      "meta": { "title": "Demo", "version": "1.0.0", "serverURL": "https://example.com/api", "apiPathPrefix": "/api" },
      "endpoints": [
        {
          "path": "/api/greet",
          "method": "GET",
          "operationId": "getGreeting",
          "responses": [{ "statusCode": 200, "contentType": "application/json", "body": "{}" }]
        }
      ]
    }
    """
    return try JSONDecoder().decode(HengeSpecSnapshot.self, from: Data(json.utf8))
}

@Suite("HengeLocalBackend", .timeLimit(.minutes(1)))
struct HengeLocalBackendTests {
    @Test func specSnapshotForwardsBuildTimeSpec() throws {
        let (store, dir) = try makeMemoryStore(pathPrefix: "")
        defer { try? FileManager.default.removeItem(at: dir) }
        let backend = HengeLocalBackend(store: store, spec: try makeSpec())
        let snapshot = backend.specSnapshot()
        #expect(snapshot.meta.serverURL == "https://example.com/api")
        #expect(snapshot.meta.apiPathPrefix == "/api")
        #expect(snapshot.endpoints.map(\.operationId) == ["getGreeting"])
        #expect(snapshot.securitySchemeCatalog == nil)
    }

    @Test func mutationsReturnLatestStoreOverrides() async throws {
        let (store, dir) = try makeMemoryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let backend = HengeLocalBackend(store: store, spec: try makeSpec())

        let configured = try await backend.configure(MockOverride(path: "/greet", method: .get, statusCode: 500))
        #expect(configured == (await store.overrides()))
        #expect(configured.map(\.path) == ["/api/greet"])
        #expect(await backend.overrides() == configured)

        let removed = try await backend.remove(configured[0])
        #expect(removed.isEmpty)

        _ = try await backend.configure(MockOverride(path: "/greet", method: .get, statusCode: 404))
        #expect(try await backend.reset().isEmpty)
        #expect(await store.overrides().isEmpty)
    }

    @Test func reloadOnMemoryOnlyStoreKeepsEdits() async throws {
        let (store, dir) = try makeMemoryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let backend = HengeLocalBackend(store: store, spec: try makeSpec())
        let configured = try await backend.configure(MockOverride(path: "/greet", method: .get, statusCode: 503))

        let response = await backend.reload()
        #expect(response == KawarimiConfigReloadResponse(result: .unchanged, overrides: configured))
        #expect(backend.reloadNoticeMessage(for: response.result) == "Reload skipped: memory-only store keeps unsaved edits.")
        #expect(await backend.scenarios().isEmpty)
    }
}
