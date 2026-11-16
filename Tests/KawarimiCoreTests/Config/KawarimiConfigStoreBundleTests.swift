import Foundation
import Testing

@testable import KawarimiCore

@Suite("KawarimiConfigStore bundle resources", .timeLimit(.minutes(1)))
struct KawarimiConfigStoreBundleTests {
    @Test func loadsOverridesAndScenariosFromBundleResources() async throws {
        let store = try KawarimiConfigStore(
            bundle: .module,
            configResource: "kawarimi",
            subdirectory: "Fixtures/BundleStore",
            pathPrefix: "/api",
            scenariosResource: "kawarimi-scenarios"
        )
        let overrides = await store.overrides()
        #expect(overrides.count == 1)
        #expect(overrides[0].path == "/api/greet")
        #expect(overrides[0].method == .get)
        #expect(overrides[0].body == "{\"ok\":true}")
        let scenarios = await store.scenarios()
        #expect(scenarios.map(\.scenarioId) == ["login"])
    }

    @Test func missingBundleResourceThrows() {
        #expect(throws: KawarimiConfigStoreError.self) {
            _ = try KawarimiConfigStore(
                bundle: .module,
                configResource: "missing-kawarimi",
                subdirectory: "Fixtures/BundleStore"
            )
        }
    }
}
