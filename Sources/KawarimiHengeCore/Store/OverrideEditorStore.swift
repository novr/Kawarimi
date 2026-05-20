import Foundation
import KawarimiCore
import Observation

/// Explorer state for the open row (``detail``). Open-from-list: ``OverrideExplorerDraftBootstrap``; queries: ``OverrideListQueries``; after Save/Reset/Del, resync with the ``[MockOverride]`` returned from the parent’s configure/remove.
@MainActor
@Observable
final class OverrideEditorStore {
    var detail: OverrideDetailDraft?

    /// Unsaved drafts stashed when switching endpoints (keyed by endpoint row).
    private var pendingDraftsByRowKey: [EndpointRowKey: OverrideDetailDraft] = [:]

    var selectedRowKey: EndpointRowKey? { detail?.endpointRowKey }

    func commitDetail(_ d: OverrideDetailDraft) {
        detail = d
    }

    func clearSelection() {
        stashCurrentDetailIfDirty()
        detail = nil
    }

    /// Sidebar / list: always **server primary** status (Spec when none).
    func displayedListStatus(
        for rowKey: EndpointRowKey,
        operationId: String,
        pathPrefix: String,
        overrides: [MockOverride]
    ) -> Int {
        OverrideListQueries.enabledStatusCode(
            for: rowKey,
            operationId: operationId,
            pathPrefix: pathPrefix,
            in: overrides
        ) ?? -1
    }

    /// Sidebar dot / “Not saved”: true when the draft’s persistable mock differs from the current `overrides` server snapshot (not merely ``OverrideDetailDraft/isDirty``).
    func hasUnsavedDraft(
        for rowKey: EndpointRowKey,
        pathPrefix: String,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride]
    ) -> Bool {
        if let d = detail, d.endpointRowKey == rowKey {
            return d.persistableMockDiffersFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: pathPrefix)
        }
        if let p = pendingDraftsByRowKey[rowKey] {
            return p.persistableMockDiffersFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: pathPrefix)
        }
        return false
    }

    private func stashCurrentDetailIfDirty() {
        guard let d = detail, d.isDirty else { return }
        pendingDraftsByRowKey[d.endpointRowKey] = d
    }

    private func clearPending(for rowKey: EndpointRowKey) {
        pendingDraftsByRowKey[rowKey] = nil
    }

    func endpointItems(endpoints: [any SpecEndpointProviding]) -> [SpecEndpointItem] {
        endpoints.map { SpecEndpointItem($0) }
    }

    func specItem(for rowKey: EndpointRowKey, endpoints: [any SpecEndpointProviding]) -> SpecEndpointItem? {
        OverrideListQueries.endpoint(for: rowKey, in: endpoints).map { SpecEndpointItem($0) }
    }

    func buildDetail(
        rowKey: EndpointRowKey,
        pathPrefix: String,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride]
    ) -> OverrideDetailDraft? {
        OverrideExplorerDraftBootstrap.makeFreshDetail(
            rowKey: rowKey,
            pathPrefix: pathPrefix,
            endpoints: endpoints,
            overrides: overrides
        )
    }

    func selectEndpoint(
        rowKey: EndpointRowKey,
        pathPrefix: String,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride]
    ) {
        stashCurrentDetailIfDirty()
        if var pending = pendingDraftsByRowKey.removeValue(forKey: rowKey) {
            pending.validationMessage = nil
            commitDetail(pending)
            return
        }
        if let built = buildDetail(rowKey: rowKey, pathPrefix: pathPrefix, endpoints: endpoints, overrides: overrides) {
            commitDetail(built)
        } else {
            detail = nil
        }
    }

    func applySelection(
        _ newKey: EndpointRowKey?,
        pathPrefix: String,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride]
    ) {
        if newKey == selectedRowKey { return }
        guard let newKey else {
            stashCurrentDetailIfDirty()
            detail = nil
            return
        }
        selectEndpoint(rowKey: newKey, pathPrefix: pathPrefix, endpoints: endpoints, overrides: overrides)
    }

    func resyncDetailAfterSpecReload(pathPrefix: String, endpoints: [any SpecEndpointProviding], overrides: [MockOverride]) {
        pendingDraftsByRowKey.removeAll()
        guard var d = detail else { return }
        d.isDirty = false
        d.validationMessage = nil
        d.resyncMockFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: pathPrefix)
        commitDetail(d)
    }

    /// Align open detail draft with a server overrides snapshot. Call from mutation completions (save / reset / disable) with the **same** list the HTTP layer just fetched (returned from `configure` / `remove` wrappers).
    func resyncDetailAfterOverridesRefresh(pathPrefix: String, endpoints: [any SpecEndpointProviding], overrides: [MockOverride]) {
        guard var d = detail, !d.isDirty else { return }
        d.validationMessage = nil
        d.resyncMockFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: pathPrefix)
        commitDetail(d)
    }

    func validateBody() {
        guard var d = detail else { return }
        let text = d.mock.body ?? ""
        let data = Data(text.utf8)
        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            d.validationMessage = EditorValidation.validJSONMessage
        } else {
            d.validationMessage = EditorValidation.invalidJSONMessage
        }
        commitDetail(d)
    }

    func formatBody() {
        guard var d = detail else { return }
        let text = d.mock.body ?? ""
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8) else {
            d.validationMessage = EditorValidation.invalidJSONCannotFormatMessage
            commitDetail(d)
            return
        }
        d.mock.body = str
        d.validationMessage = EditorValidation.formattedMessage
        d.isDirty = true
        d.pinnedNumberedResponseChip = false
        commitDetail(d)
    }

    func applyMockEdit(from item: SpecEndpointItem, newMock: MockOverride) {
        guard var d = detail else { return }
        let sameRow = d.endpointRowKey == item.rowKey
        let sameOp = d.endpointRowKey.method == item.rowKey.method
            && d.mock.name == item.endpoint.operationId
            && !(item.endpoint.operationId.isEmpty)
        guard sameRow || sameOp else { return }
        var m = newMock
        m.path = item.endpoint.path
        m.method = item.endpoint.method
        m.name = item.endpoint.operationId
        d.mock = m
        d.isDirty = true
        d.validationMessage = nil
        d.pinnedNumberedResponseChip = false
        commitDetail(d)
    }

    func markSavedClean() {
        guard var d = detail else { return }
        clearPending(for: d.endpointRowKey)
        d.isDirty = false
        d.validationMessage = nil
        commitDetail(d)
    }

    func applyServerReset(mock: MockOverride, rowKey: EndpointRowKey) {
        clearPending(for: rowKey)
        guard var d = detail, d.endpointRowKey == rowKey else { return }
        d.mock = mock
        d.pinnedNumberedResponseChip = false
        d.isDirty = false
        d.validationMessage = nil
        commitDetail(d)
    }

    func pinnedNumberedResponseChip(for rowKey: EndpointRowKey) -> Bool {
        guard let d = detail, d.endpointRowKey == rowKey else { return false }
        return d.pinnedNumberedResponseChip
    }

    func setPinnedNumberedResponseChip(_ value: Bool) {
        guard var d = detail else { return }
        d.pinnedNumberedResponseChip = value
        commitDetail(d)
    }

    func setDetailValidationMessage(_ message: String?) {
        guard var d = detail else { return }
        d.validationMessage = message
        commitDetail(d)
    }

    /// **Save** — ``SavePayload.build``: Spec-only disable when on **Spec**, else **`mock.isEnabled`** or **numbered chip pin** (enabled → primary; disabled → row off with body preserved).
    ///
    /// `configureOverride` must return the overrides list **after** the server reflects the write (same array the UI would show), so ``resyncDetailAfterOverridesRefresh`` does not read a stale snapshot.
    func applyWithBody(
        endpointItem: SpecEndpointItem,
        pathPrefix: String = "",
        endpoints: [any SpecEndpointProviding] = [],
        configureOverride: @escaping (MockOverride) async throws -> [MockOverride],
        setErrorMessage: @escaping (String?) -> Void
    ) async {
        await applyWithPayloadBuilder(
            endpointItem: endpointItem,
            pathPrefix: pathPrefix,
            endpoints: endpoints,
            build: {
                SavePayload.build(
                    mock: $0.mock,
                    endpoint: endpointItem.endpoint,
                    pinnedNumberedResponseChip: $0.pinnedNumberedResponseChip
                )
            },
            configureOverride: configureOverride,
            setErrorMessage: setErrorMessage
        )
    }

    private func applyWithPayloadBuilder(
        endpointItem: SpecEndpointItem,
        pathPrefix: String,
        endpoints: [any SpecEndpointProviding],
        build: (OverrideDetailDraft) -> MockOverride,
        configureOverride: @escaping (MockOverride) async throws -> [MockOverride],
        setErrorMessage: @escaping (String?) -> Void
    ) async {
        setErrorMessage(nil)
        guard var draft = detail, draft.endpointRowKey == endpointItem.rowKey else { return }
        let override = build(draft)
        do {
            let refreshed = try await configureOverride(override)
            draft.mock.isEnabled = override.isEnabled
            draft.mock.statusCode = override.statusCode
            draft.mock.exampleId = override.exampleId
            draft.mock.body = override.body
            draft.mock.contentType = override.contentType
            draft.pinnedNumberedResponseChip = false
            commitDetail(draft)
            markSavedClean()
            resyncDetailAfterOverridesRefresh(pathPrefix: pathPrefix, endpoints: endpoints, overrides: refreshed)
        } catch {
            setErrorMessage(error.localizedDescription)
        }
    }

    func clearOverride(
        endpointItem: SpecEndpointItem,
        pathPrefix: String = "",
        endpoints: [any SpecEndpointProviding] = [],
        configureOverride: @escaping (MockOverride) async throws -> [MockOverride],
        setErrorMessage: @escaping (String?) -> Void
    ) async {
        let endpoint = endpointItem.endpoint
        setErrorMessage(nil)
        let reset = MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: endpoint.responseList.first?.statusCode ?? 200,
            exampleId: nil,
            isEnabled: false,
            body: nil,
            contentType: nil
        )
        do {
            let refreshed = try await configureOverride(reset)
            applyServerReset(mock: reset, rowKey: endpointItem.rowKey)
            resyncDetailAfterOverridesRefresh(pathPrefix: pathPrefix, endpoints: endpoints, overrides: refreshed)
        } catch {
            setErrorMessage(error.localizedDescription)
        }
    }

    func disableCurrentMockRow(
        endpointItem: SpecEndpointItem,
        pathPrefix: String,
        overrides: [MockOverride],
        endpoints: [any SpecEndpointProviding] = [],
        configureOverride: @escaping (MockOverride) async throws -> [MockOverride],
        removeOverride: @escaping (MockOverride) async throws -> [MockOverride],
        setErrorMessage: @escaping (String?) -> Void
    ) async {
        let endpoint = endpointItem.endpoint
        setErrorMessage(nil)
        guard let draft = detail, draft.endpointRowKey == endpointItem.rowKey else { return }
        let plan = DisableMockPlanner.plan(
            mock: draft.mock,
            endpoint: endpoint,
            rowKey: endpointItem.rowKey,
            pathPrefix: pathPrefix,
            overrides: overrides
        )
        do {
            switch plan {
            case .none:
                break
            case let .configureDisable(payload):
                let refreshed = try await configureOverride(payload)
                markSavedClean()
                resyncDetailAfterOverridesRefresh(
                    pathPrefix: pathPrefix,
                    endpoints: endpoints,
                    overrides: refreshed
                )
            case let .removeThenReset(removeKey, cleared):
                let refreshed = try await removeOverride(removeKey)
                applyServerReset(mock: cleared, rowKey: endpointItem.rowKey)
                markSavedClean()
                resyncDetailAfterOverridesRefresh(
                    pathPrefix: pathPrefix,
                    endpoints: endpoints,
                    overrides: refreshed
                )
            }
        } catch {
            setErrorMessage(error.localizedDescription)
        }
    }

}
