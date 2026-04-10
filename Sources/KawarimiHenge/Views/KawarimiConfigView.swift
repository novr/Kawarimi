import KawarimiCore
import SwiftUI

/// Host view for Henge: owns **HTTP-backed** spec and overrides snapshots, and passes them into ``OverrideEditorView``.
///
/// **Snapshots** (`meta`, `endpoints`, `overridesSnapshot`, `overridesRevision`) update from ``loadSpecAndOverrides()`` and ``refreshOverridesOnly()``.
/// **Mutation closures** passed to the child return the same ``[MockOverride]`` as ``refreshOverridesOnly()`` (never re-read ``overridesSnapshot`` for that return) so ``OverrideEditorStore`` can resync the open draft reliably (see *UI data flow* in the henge documentation).
public struct KawarimiConfigView: View {
    private let serverURL: String

    private let specProvider: () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding])
    private let fetchOverrides: () async throws -> [MockOverride]
    private let configureOverride: (MockOverride) async throws -> Void
    private let removeOverride: (MockOverride) async throws -> Void
    private let resetAllOverrides: () async throws -> Void

    @State private var meta: (any SpecMetaProviding)?
    @State private var endpoints: [any SpecEndpointProviding] = []
    @State private var overridesSnapshot: [MockOverride] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Bumps after a successful spec + overrides fetch so the child reruns `.task(id:)`.
    @State private var specLoadID = 0
    /// Bumps after overrides-only refresh (e.g. after configure) so the child reruns `.task(id:)`.
    @State private var overridesRevision = 0

    /// Wires the mock UI to Henge HTTP via ``KawarimiAPIClient``.
    ///
    /// Pass your generated `SpecResponse.self` for `specType` (it conforms to ``KawarimiFetchedSpec``).
    public init<Spec: KawarimiFetchedSpec>(client: KawarimiAPIClient, specType: Spec.Type) {
        serverURL = client.baseURL.absoluteString
        specProvider = {
            let decoded = try await client.fetchSpec(as: specType)
            return (meta: decoded.meta, endpoints: decoded.endpoints)
        }
        fetchOverrides = { try await client.fetchOverrides() }
        configureOverride = { try await client.configure(override: $0) }
        removeOverride = { try await client.removeOverride(override: $0) }
        resetAllOverrides = { try await client.reset() }
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
            meta: meta,
            endpoints: endpoints,
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
        defer { isLoading = false }
        do {
            let spec = try await specProvider()
            let overrides = try await fetchOverrides()
            meta = spec.meta
            endpoints = spec.endpoints
            overridesSnapshot = overrides
            specLoadID += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performResetAll() async throws {
        try await resetAllOverrides()
        await loadSpecAndOverrides()
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
