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
    private let configureOnServer: (MockOverride) async throws -> [MockOverride]
    private let removeOnServer: (MockOverride) async throws -> [MockOverride]
    private let resetAllOnServer: () async throws -> [MockOverride]
    private let reloadFromDisk: () async throws -> KawarimiConfigReloadResponse

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
        configureOnServer = { try await client.configure(override: $0) }
        removeOnServer = { try await client.removeOverride(override: $0) }
        resetAllOnServer = { try await client.reset() }
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
                var list = overridesSnapshot
                if override.isEnabled {
                    list = try await disableConflictingStatusMocks(saved: override, starting: list)
                }
                list = try await configureOnServer(override)
                return applyOverridesSnapshot(list)
            },
            removeOverride: { override in
                let list = try await removeOnServer(override)
                return applyOverridesSnapshot(list)
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
        _ = applyOverridesSnapshot(try await resetAllOnServer())
        specLoadID += 1
    }

    private func performReloadFromDisk() async {
        guard !isReloadingFromDisk else { return }
        isReloadingFromDisk = true
        errorMessage = nil
        reloadNoticeMessage = nil
        defer { isReloadingFromDisk = false }
        do {
            let response = try await reloadFromDisk()
            reloadNoticeMessage = KawarimiConfigReloadPresentation.noticeMessage(for: response.result)
            _ = applyOverridesSnapshot(response.overrides)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    private func applyOverridesSnapshot(_ list: [MockOverride]) -> [MockOverride] {
        errorMessage = nil
        overridesSnapshot = list
        overridesRevision += 1
        return list
    }

    /// When saving an enabled mock, turn off every **other** enabled override for the same OpenAPI operation
    /// (different status **or** same status with a different `exampleId`) so only one row stays active.
    private func disableConflictingStatusMocks(
        saved: MockOverride,
        starting: [MockOverride]
    ) async throws -> [MockOverride] {
        let pathPrefix = meta?.apiPathPrefix ?? ""
        var list = starting
        for other in list where OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow(
            saved: saved,
            peer: other,
            pathPrefix: pathPrefix
        ) {
            var dis = other
            dis.isEnabled = false
            list = try await configureOnServer(dis)
        }
        return list
    }
}
