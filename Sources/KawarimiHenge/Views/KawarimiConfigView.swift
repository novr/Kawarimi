import KawarimiCore
import SwiftUI

public struct KawarimiConfigView: View {
    public let serverURL: String

    private let specProvider: () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding])
    private let fetchOverrides: () async throws -> [MockOverride]
    private let configureOverride: (MockOverride) async throws -> Void
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

    public init(
        serverURL: String,
        specProvider: @escaping () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding]),
        fetchOverrides: @escaping () async throws -> [MockOverride],
        configureOverride: @escaping (MockOverride) async throws -> Void,
        resetAllOverrides: @escaping () async throws -> Void
    ) {
        self.serverURL = serverURL
        self.specProvider = specProvider
        self.fetchOverrides = fetchOverrides
        self.configureOverride = configureOverride
        self.resetAllOverrides = resetAllOverrides
    }

    public var body: some View {
        OverrideEditorView(
            serverURL: serverURL,
            onRefresh: { Task { await loadSpecAndOverrides() } },
            onResetAll: { Task { await performResetAll() } },
            meta: meta,
            endpoints: endpoints,
            overrides: overridesSnapshot,
            isLoading: isLoading,
            specLoadID: specLoadID,
            overridesRevision: overridesRevision,
            configureOverride: { override in
                try await configureOverride(override)
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

    private func performResetAll() async {
        try? await resetAllOverrides()
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
}
