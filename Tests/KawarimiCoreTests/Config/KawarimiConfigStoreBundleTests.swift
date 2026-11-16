import Foundation
import Testing

@testable import KawarimiCore

@Suite("KawarimiConfigStore bundle resources", .timeLimit(.minutes(1)))
struct KawarimiConfigStoreBundleTests {
    @Test func loadsOverridesAndScenariosFromConfigURL() async throws {
        let configURL = try #require(
            Bundle.module.url(forResource: "kawarimi", withExtension: "json", subdirectory: "Fixtures/BundleStore")
        )
        let scenariosURL = try #require(
            Bundle.module.url(
                forResource: "kawarimi-scenarios",
                withExtension: "json",
                subdirectory: "Fixtures/BundleStore"
            )
        )
        let store = try KawarimiConfigStore(
            configURL: configURL,
            pathPrefix: "/api",
            scenariosURL: scenariosURL
        )
        let overrides = await store.overrides()
        #expect(overrides.count == 1)
        #expect(overrides[0].path == "/api/greet")
        #expect(overrides[0].method == .get)
        #expect(overrides[0].body == "{\"ok\":true}")
        let scenarios = await store.scenarios()
        #expect(scenarios.map(\.scenarioId) == ["login"])
    }

    @Test func bundleResourceConvenienceLoadsSameFiles() async throws {
        let store = try KawarimiConfigStore(
            bundle: .module,
            configResource: "kawarimi",
            subdirectory: "Fixtures/BundleStore",
            pathPrefix: "/api",
            scenariosResource: "kawarimi-scenarios"
        )
        let overrides = await store.overrides()
        #expect(overrides.count == 1)
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

    @Test func nonFileConfigURLThrows() {
        let url = URL(string: "https://example.com/kawarimi.json")!
        #expect(throws: KawarimiConfigStoreError.self) {
            _ = try KawarimiConfigStore(configURL: url)
        }
    }

    @Test func nonFileScenariosURLThrows() throws {
        let configURL = try #require(
            Bundle.module.url(forResource: "kawarimi", withExtension: "json", subdirectory: "Fixtures/BundleStore")
        )
        let scenariosURL = URL(string: "https://example.com/kawarimi-scenarios.json")!
        #expect(throws: KawarimiConfigStoreError.self) {
            _ = try KawarimiConfigStore(configURL: configURL, scenariosURL: scenariosURL)
        }
    }
}
