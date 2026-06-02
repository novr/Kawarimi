import KawarimiCore
import KawarimiHengeCore
import SwiftUI

/// Henge root: loads spec and overrides, passes snapshots into ``OverrideEditorView``. Configure/remove callbacks must return the same ``[MockOverride]`` as the overrides refresh (see henge *UI data flow*).
public struct KawarimiConfigView: View {
    private let specProvider: () async throws -> (
        meta: any SpecMetaProviding,
        endpoints: [any SpecEndpointProviding],
        securitySchemeCatalog: [any SpecSecuritySchemeProviding]?
    )
    private let fetchOverrides: () async throws -> [MockOverride]
    private let configureOverride: (MockOverride) async throws -> Void
    private let removeOverride: (MockOverride) async throws -> Void
    private let resetAllOverrides: () async throws -> Void
    private let reloadFromDisk: () async throws -> KawarimiConfigReloadResult

    @State private var serverURL: String
    @State private var meta: (any SpecMetaProviding)?
    @State private var endpoints: [any SpecEndpointProviding] = []
    @State private var securitySchemeCatalog: [any SpecSecuritySchemeProviding]?
    @State private var overridesSnapshot: [MockOverride] = []
    @State private var isLoading = false
    @State private var isReloadingFromDisk = false
    @State private var reloadNoticeMessage: String?
    @State private var errorMessage: String?
    /// Bumps after a successful spec + overrides fetch so the child reruns `.task(id:)`.
    @State private var specLoadID = 0
    /// Bumps after overrides-only refresh (e.g. after configure) so the child reruns `.task(id:)`.
    @State private var overridesRevision = 0

    /// Wires the mock UI to Henge HTTP via ``KawarimiAPIClient`` (`GET …/__kawarimi/spec` + status/admin routes).
    public init(client: KawarimiAPIClient) {
        _serverURL = State(initialValue: client.baseURL.absoluteString)
        specProvider = {
            let decoded = try await client.fetchHengeSpec()
            return (
                meta: decoded.meta,
                endpoints: decoded.endpoints,
                securitySchemeCatalog: decoded.securitySchemeCatalog
            )
        }
        fetchOverrides = { try await client.fetchOverrides() }
        configureOverride = { try await client.configure(override: $0) }
        removeOverride = { try await client.removeOverride(override: $0) }
        resetAllOverrides = { try await client.reset() }
        reloadFromDisk = { try await client.reload() }
    }

    public var body: some View {
        OverrideEditorView(
            serverURL: serverURL,
            onRefresh: { Task { await loadSpecAndOverrides() } },
            onResetAll: {
                Task { @MainActor in
                    do {
                        try await performResetAll()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            },
            onReloadFromDisk: {
                Task { @MainActor in
                    await performReloadFromDisk()
                }
            },
            reloadNoticeMessage: reloadNoticeMessage,
            isReloadingFromDisk: isReloadingFromDisk,
            meta: meta,
            endpoints: endpoints,
            securitySchemeCatalog: securitySchemeCatalog,
            overrides: overridesSnapshot,
            isLoading: isLoading,
            specLoadID: specLoadID,
            overridesRevision: overridesRevision,
            configureOverride: { override in
                if override.isEnabled {
                    try await disableConflictingStatusMocks(saved: override)
                }
                try await configureOverride(override)
                return try await refreshOverridesOnly()
            },
            removeOverride: { override in
                try await removeOverride(override)
                return try await refreshOverridesOnly()
            },
            errorMessage: $errorMessage
        )
        .task {
            await loadSpecAndOverrides()
        }
    }

    private func loadSpecAndOverrides() async {
        isLoading = true
        errorMessage = nil
        reloadNoticeMessage = nil
        defer { isLoading = false }
        do {
            let spec = try await specProvider()
            let overrides = try await fetchOverrides()
            meta = spec.meta
            serverURL = spec.meta.serverURL
            endpoints = spec.endpoints
            securitySchemeCatalog = spec.securitySchemeCatalog
            overridesSnapshot = overrides
            specLoadID += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performResetAll() async throws {
        reloadNoticeMessage = nil
        try await resetAllOverrides()
        await loadSpecAndOverrides()
    }

    private func performReloadFromDisk() async {
        guard !isReloadingFromDisk else { return }
        isReloadingFromDisk = true
        errorMessage = nil
        reloadNoticeMessage = nil
        defer { isReloadingFromDisk = false }
        do {
            let result = try await reloadFromDisk()
            reloadNoticeMessage = KawarimiConfigReloadPresentation.noticeMessage(for: result)
            do {
                _ = try await refreshOverridesOnly()
            } catch {
                errorMessage = KawarimiConfigReloadPresentation.refreshFailureMessage(after: result, error: error)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches overrides, updates ``overridesSnapshot`` / ``overridesRevision``, and returns the **same** array for callers that must resync without re-reading `@State`.
    @discardableResult
    private func refreshOverridesOnly() async throws -> [MockOverride] {
        errorMessage = nil
        let list = try await fetchOverrides()
        overridesSnapshot = list
        overridesRevision += 1
        return list
    }

    /// When saving an enabled mock, turn off every **other** enabled override for the same OpenAPI operation
    /// (different status **or** same status with a different `exampleId`) so only one row stays active.
    private func disableConflictingStatusMocks(saved: MockOverride) async throws {
        let pathPrefix = meta?.apiPathPrefix ?? ""
        let all = try await fetchOverrides()
        for other in all where OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow(
            saved: saved,
            peer: other,
            pathPrefix: pathPrefix
        ) {
            var dis = other
            dis.isEnabled = false
            try await configureOverride(dis)
        }
    }
}
