import KawarimiCore

/// Henge operations against an in-process ``KawarimiConfigStore`` and a build-time spec, without the admin HTTP API.
///
/// Mutations return ``KawarimiConfigStore/overrides()`` afterwards, matching the admin routes that `KawarimiConfigView` expects.
package struct HengeLocalBackend<Spec: KawarimiFetchedSpec>: Sendable {
    private let store: KawarimiConfigStore
    private let spec: Spec

    package init(store: KawarimiConfigStore, spec: Spec) {
        self.store = store
        self.spec = spec
    }

    package func specSnapshot() -> (
        meta: any SpecMetaProviding,
        endpoints: [any SpecEndpointProviding],
        securitySchemeCatalog: [any SpecSecuritySchemeProviding]?
    ) {
        (
            meta: spec.meta,
            endpoints: spec.endpoints,
            securitySchemeCatalog: spec.securitySchemeCatalog
        )
    }

    package func overrides() async -> [MockOverride] {
        await store.overrides()
    }

    package func scenarios() async -> [KawarimiScenario] {
        await store.scenarios()
    }

    package func configure(_ override: MockOverride) async throws -> [MockOverride] {
        try await store.configure(override)
        return await store.overrides()
    }

    package func remove(_ override: MockOverride) async throws -> [MockOverride] {
        try await store.removeOverride(override)
        return await store.overrides()
    }

    package func reset() async throws -> [MockOverride] {
        try await store.reset()
        return await store.overrides()
    }

    package func reloadNoticeMessage(for result: KawarimiConfigReloadResult) -> String {
        KawarimiConfigReloadPresentation.localNoticeMessage(for: result, persistence: store.persistence)
    }

    package func reload() async -> KawarimiConfigReloadResponse {
        let result = await store.reloadFromDisk()
        return KawarimiConfigReloadResponse(result: result, overrides: await store.overrides())
    }
}
