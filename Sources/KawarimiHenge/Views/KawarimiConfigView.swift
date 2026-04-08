import KawarimiCore
import SwiftUI

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
                try await configureOverride(override)
                if override.isEnabled {
                    try await disableConflictingStatusMocks(saved: override)
                }
                await refreshOverridesOnly()
            },
            removeOverride: { override in
                try await removeOverride(override)
                await refreshOverridesOnly()
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

    private func refreshOverridesOnly() async {
        errorMessage = nil
        do {
            overridesSnapshot = try await fetchOverrides()
            overridesRevision += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// When saving an enabled mock, turn off other enabled mocks for the same OpenAPI operation that use a **different HTTP status**.
    /// Otherwise the interceptor tie-break keeps e.g. 200 ahead of 503 and the list / API calls follow “Default” even though 503 was saved.
    private func disableConflictingStatusMocks(saved: MockOverride) async throws {
        let pathPrefix = meta?.apiPathPrefix ?? ""
        let all = try await fetchOverrides()
        for other in all where Self.shouldDisableOtherEnabledMock(
            saved: saved,
            other: other,
            pathPrefix: pathPrefix
        ) {
            var dis = other
            dis.isEnabled = false
            dis.body = nil
            dis.contentType = nil
            try await configureOverride(dis)
        }
    }

    private static func shouldDisableOtherEnabledMock(
        saved: MockOverride,
        other: MockOverride,
        pathPrefix: String
    ) -> Bool {
        guard other.isEnabled else { return false }
        guard saved.method == other.method else { return false }
        guard sameOpenAPIOperation(saved, other, pathPrefix: pathPrefix) else { return false }
        guard saved.statusCode != other.statusCode else { return false }
        return true
    }

    /// Treats spec paths (e.g. `/greet`) and stored paths (e.g. `/api/greet`) as the same operation when prefixes align.
    private static func sameOpenAPIOperation(
        _ a: MockOverride,
        _ b: MockOverride,
        pathPrefix: String
    ) -> Bool {
        let na = a.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nb = b.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !na.isEmpty, !nb.isEmpty {
            return na == nb
        }
        let pa = KawarimiPath.aligned(path: a.path, pathPrefix: pathPrefix)
        let pb = KawarimiPath.aligned(path: b.path, pathPrefix: pathPrefix)
        return pa == pb
    }
}
