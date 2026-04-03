import Foundation
import KawarimiCore
import Observation

@Observable
final class OverrideEditorStore {
    var detail: OverrideDetailDraft?

    /// Must match ``KawarimiConfigStore`` / spec `apiPathPrefix` so override paths align with list rows.
    var apiPathPrefix: String = OpenAPIPathPrefix.defaultMountPath

    var selectedRowKey: EndpointRowKey? { detail?.endpointRowKey }

    func commitDetail(_ d: OverrideDetailDraft) {
        detail = d
    }

    func clearSelection() {
        detail = nil
    }

    func displayedListStatus(
        for rowKey: EndpointRowKey,
        operationId: String,
        overrides: [MockOverride]
    ) -> Int {
        if let d = detail, d.endpointRowKey == rowKey {
            if d.mock.isEnabled {
                return d.mock.statusCode
            }
            // Current chip is off; still show this operation's primary enabled mock if any (same as when unselected).
            if let code = OverrideListQueries.enabledStatusCode(
                for: rowKey,
                operationId: operationId,
                pathPrefix: apiPathPrefix,
                in: overrides
            ) {
                return code
            }
            return -1
        }
        if let code = OverrideListQueries.enabledStatusCode(
            for: rowKey,
            operationId: operationId,
            pathPrefix: apiPathPrefix,
            in: overrides
        ) {
            return code
        }
        return -1
    }

    func endpointItems(endpoints: [any SpecEndpointProviding]) -> [SpecEndpointItem] {
        endpoints.map { SpecEndpointItem($0) }
    }

    func specItem(for rowKey: EndpointRowKey, endpoints: [any SpecEndpointProviding]) -> SpecEndpointItem? {
        OverrideListQueries.endpoint(for: rowKey, in: endpoints).map { SpecEndpointItem($0) }
    }

    func buildDetail(rowKey: EndpointRowKey, endpoints: [any SpecEndpointProviding], overrides: [MockOverride]) -> OverrideDetailDraft? {
        guard let endpoint = OverrideListQueries.endpoint(for: rowKey, in: endpoints) else { return nil }
        let mock = MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: endpoint.responseList.first?.statusCode ?? 200,
            isEnabled: false,
            body: nil,
            contentType: nil
        )
        var draft = OverrideDetailDraft(mock: mock, validationMessage: nil, isDirty: false)
        draft.resyncMockFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: apiPathPrefix)
        return draft
    }

    func selectEndpoint(rowKey: EndpointRowKey, endpoints: [any SpecEndpointProviding], overrides: [MockOverride]) {
        if let built = buildDetail(rowKey: rowKey, endpoints: endpoints, overrides: overrides) {
            commitDetail(built)
        } else {
            clearSelection()
        }
    }

    func applySelection(
        _ newKey: EndpointRowKey?,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride]
    ) {
        if newKey == selectedRowKey { return }
        guard let newKey else {
            clearSelection()
            return
        }
        selectEndpoint(rowKey: newKey, endpoints: endpoints, overrides: overrides)
    }

    func resyncDetailAfterSpecReload(endpoints: [any SpecEndpointProviding], overrides: [MockOverride]) {
        guard var d = detail else { return }
        d.isDirty = false
        d.validationMessage = nil
        d.resyncMockFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: apiPathPrefix)
        commitDetail(d)
    }

    func resyncDetailAfterOverridesRefresh(endpoints: [any SpecEndpointProviding], overrides: [MockOverride]) {
        guard var d = detail, !d.isDirty else { return }
        d.validationMessage = nil
        d.resyncMockFromServer(overrides: overrides, endpoints: endpoints, pathPrefix: apiPathPrefix)
        commitDetail(d)
    }

    func validateBody() {
        guard var d = detail else { return }
        let text = d.mock.body ?? ""
        let data = Data(text.utf8)
        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            d.validationMessage = "Valid JSON"
        } else {
            d.validationMessage = "Invalid JSON"
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
            d.validationMessage = "Invalid JSON (cannot format)"
            commitDetail(d)
            return
        }
        d.mock.body = str
        d.validationMessage = "Formatted"
        d.isDirty = true
        commitDetail(d)
    }

    func applyMockEdit(from item: SpecEndpointItem, newMock: MockOverride) {
        guard var d = detail else { return }
        // Prefer row-key match; also accept operationId when path strings diverge (e.g. configured vs spec path).
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
        commitDetail(d)
    }

    func markSavedClean() {
        guard var d = detail else { return }
        d.isDirty = false
        d.validationMessage = nil
        commitDetail(d)
    }

    func applyServerReset(mock: MockOverride, rowKey: EndpointRowKey) {
        guard var d = detail, d.endpointRowKey == rowKey else { return }
        d.mock = mock
        d.isDirty = false
        d.validationMessage = nil
        commitDetail(d)
    }

}
