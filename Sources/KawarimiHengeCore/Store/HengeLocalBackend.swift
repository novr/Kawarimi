import KawarimiCore

/// Henge operations against an in-process ``KawarimiConfigStore`` and a build-time spec, without the admin HTTP API.
///
/// Mutations return ``KawarimiConfigStore/overrides()`` afterwards, matching the admin routes that `KawarimiConfigView` expects.
public struct HengeLocalBackend<Spec: KawarimiFetchedSpec>: Sendable {
    public let store: KawarimiConfigStore
    public let spec: Spec

    public init(store: KawarimiConfigStore, spec: Spec) {
        self.store = store
        self.spec = spec
    }

    public func specSnapshot() -> (
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

    public func overrides() async -> [MockOverride] {
        await store.overrides()
    }

    public func scenarios() async -> [KawarimiScenario] {
        await store.scenarios()
    }

    public func configure(_ override: MockOverride) async throws -> [MockOverride] {
        try await store.configure(override)
        return await store.overrides()
    }

    public func remove(_ override: MockOverride) async throws -> [MockOverride] {
        try await store.removeOverride(override)
        return await store.overrides()
    }

    public func reset() async throws -> [MockOverride] {
        try await store.reset()
        return await store.overrides()
    }

    public func reload() async -> KawarimiConfigReloadResponse {
        let result = await store.reloadFromDisk()
        return KawarimiConfigReloadResponse(result: result, overrides: await store.overrides())
    }
}
