import Foundation
import HTTPTypes
import KawarimiCore
import Testing
@testable import KawarimiHengeCore

private struct FakeSpecResponse: SpecMockResponseProviding {
    var statusCode: Int
    var contentType: String
    var body: String
    var exampleId: String?
    var summary: String?
    var description: String?
}

private struct FakeSpecEndpoint: SpecEndpointProviding {
    var path: String
    var method: HTTPRequest.Method
    var operationId: String
    var responseList: [any SpecMockResponseProviding]
}

private enum TestAsyncError: LocalizedError {
    case kaboom
    var errorDescription: String? { "kaboom" }
}

// MARK: ``OverrideEditorStore/applyWithBody``

@MainActor
@Test(.timeLimit(.minutes(1))) func savePropagatesErrorViaSetter() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: true, body: "{}", contentType: "application/json"),
        validationMessage: nil,
        isDirty: true
    )
    var lastError: String?
    await store.applyWithBody(
        endpointItem: item,
        configureOverride: { _ in throw TestAsyncError.kaboom },
        removeOverride: { _ in [] },
        setErrorMessage: { lastError = $0 }
    )
    #expect(lastError == "kaboom")
    #expect(store.detail?.isDirty == true)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func saveEnabledClearsErrorThenSuccessUpdatesDraft() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: true, body: "{}", contentType: "application/json"),
        validationMessage: nil,
        isDirty: true
    )
    var steps: [String?] = []
    await store.applyWithBody(
        endpointItem: item,
        configureOverride: { sent in
            #expect(sent.isEnabled == true)
            return [sent]
        },
        removeOverride: { _ in [] },
        setErrorMessage: { steps.append($0) }
    )
    #expect(steps == [nil])
    #expect(store.detail?.isDirty == false)
}

/// After save, ``OverrideEditorStore/applyWithBody`` must resync from the list returned by `configureOverride` (post-fetch), not only merge the outbound payload — otherwise UI chips / primary state can stay on pre-save identity.
@MainActor
@Test(.timeLimit(.minutes(1))) func applyWithBodyFreshOverridesResyncAdoptsServerExampleId() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: true, body: "{}", contentType: "application/json"),
        validationMessage: nil,
        isDirty: true
    )
    let fromServer = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: "serverExample",
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    await store.applyWithBody(
        endpointItem: item,
        pathPrefix: "",
        endpoints: [endpoint],
        configureOverride: { _ in [fromServer] },
        removeOverride: { _ in [] },
        setErrorMessage: { _ in }
    )
    #expect(store.detail?.mock.exampleId == "serverExample")
    #expect(store.detail?.isDirty == false)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func applyWithBodyResyncKeepsCustom503Enabled() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let ex = "cust01"
    let server503 = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 503,
        exampleId: ex,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    store.detail = OverrideDetailDraft(
        mock: MockOverride(name: "op", path: "/p", method: .get, statusCode: 503, exampleId: ex, isEnabled: true, body: "{}", contentType: "application/json"),
        validationMessage: nil,
        isDirty: true
    )
    await store.applyWithBody(
        endpointItem: item,
        pathPrefix: "",
        endpoints: [endpoint],
        configureOverride: { _ in [server503] },
        removeOverride: { _ in [] },
        setErrorMessage: { _ in }
    )
    #expect(store.detail?.mock.statusCode == 503)
    #expect(store.detail?.mock.isEnabled == true)
    #expect(store.detail?.mock.exampleId == ex)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func saveDisabledSendsBodyAndIsEnabledFalse() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: "{\"x\":1}", contentType: "application/json"),
        validationMessage: nil,
        isDirty: true
    )
    var steps: [String?] = []
    await store.applyWithBody(
        endpointItem: item,
        configureOverride: { sent in
            #expect(sent.isEnabled == false)
            #expect(sent.statusCode == 200)
            #expect(sent.body == "{\"x\":1}")
            return [sent]
        },
        removeOverride: { _ in [] },
        setErrorMessage: { steps.append($0) }
    )
    #expect(steps == [nil])
    #expect(store.detail?.isDirty == false)
    #expect(store.detail?.mock.isEnabled == false)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func applyWithBodySkipsConfiguratorWhenDetailMissing() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    var callCount = 0
    await store.applyWithBody(
        endpointItem: item,
        configureOverride: { _ in
            callCount += 1
            return []
        },
        removeOverride: { _ in [] },
        setErrorMessage: { _ in }
    )
    #expect(callCount == 0)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func applyWithBodySpecOnlySaveRemovesStoredGhostRow() async {
    let endpoint = FakeSpecEndpoint(
        path: "/api/greet",
        method: .get,
        operationId: "getGreeting",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{\"message\":\"Hello\"}", exampleId: "success", summary: nil, description: nil),
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{\"message\":\"Formal\"}", exampleId: "formal", summary: nil, description: nil),
        ]
    )
    let item = SpecEndpointItem(endpoint)
    let storedGhost = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: nil,
        contentType: nil
    )
    let store = OverrideEditorStore()
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "getGreeting",
            path: "/api/greet",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: false,
            body: nil,
            contentType: nil
        ),
        validationMessage: nil,
        isDirty: true
    )
    var configureCalls = 0
    var removeCalls = 0
    await store.applyWithBody(
        endpointItem: item,
        pathPrefix: "/api",
        endpoints: [endpoint],
        overrides: [storedGhost],
        configureOverride: { _ in
            configureCalls += 1
            return [storedGhost]
        },
        removeOverride: { key in
            removeCalls += 1
            #expect(key.statusCode == 200)
            #expect(key.exampleId == nil)
            return []
        },
        setErrorMessage: { _ in }
    )
    #expect(configureCalls == 0)
    #expect(removeCalls == 1)
    #expect(store.detail?.isDirty == false)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func disableCurrentMockRowClearDraftLocallySkipsServerCalls() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "op",
            path: "/p",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "{\"custom\":true}",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: true
    )
    var configureCalls = 0
    var removeCalls = 0
    await store.disableCurrentMockRow(
        endpointItem: item,
        pathPrefix: "",
        overrides: [],
        endpoints: [endpoint],
        configureOverride: { _ in
            configureCalls += 1
            return []
        },
        removeOverride: { _ in
            removeCalls += 1
            return []
        },
        setErrorMessage: { _ in }
    )
    #expect(configureCalls == 0)
    #expect(removeCalls == 0)
    #expect(store.detail?.isDirty == false)
    #expect(store.detail?.mock.isEnabled == false)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func disableCurrentMockRowRemoveStoredRowCallsRemoveOnly() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let stored = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    store.detail = OverrideDetailDraft(
        mock: stored,
        validationMessage: nil,
        isDirty: false
    )
    var configureCalls = 0
    var removeCalls = 0
    await store.disableCurrentMockRow(
        endpointItem: item,
        pathPrefix: "",
        overrides: [stored],
        endpoints: [endpoint],
        configureOverride: { _ in
            configureCalls += 1
            return []
        },
        removeOverride: { _ in
            removeCalls += 1
            return []
        },
        setErrorMessage: { _ in }
    )
    #expect(configureCalls == 0)
    #expect(removeCalls == 1)
    #expect(store.detail?.isDirty == false)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func clearOverrideAndDisableMockRowPropagateConfiguratorErrors() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: true, body: "{}", contentType: nil),
        validationMessage: nil,
        isDirty: false
    )
    var err: String?
    let storedGhost = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: nil,
        contentType: nil
    )
    await store.clearOverride(
        endpointItem: item,
        overrides: [storedGhost],
        configureOverride: { _ in throw TestAsyncError.kaboom },
        removeOverride: { _ in throw TestAsyncError.kaboom },
        setErrorMessage: { err = $0 }
    )
    #expect(err == "kaboom")

    err = nil
    let stored = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    await store.disableCurrentMockRow(
        endpointItem: item,
        pathPrefix: "/api",
        overrides: [stored],
        configureOverride: { _ in throw TestAsyncError.kaboom },
        removeOverride: { _ in throw TestAsyncError.kaboom },
        setErrorMessage: { err = $0 }
    )
    #expect(err == "kaboom")
}

@MainActor
@Test(.timeLimit(.minutes(1))) func removeDisabledOverridesForOperationSkipsWhenNone() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    var removeCalls = 0
    await store.removeDisabledOverridesForOperation(
        endpointItem: item,
        pathPrefix: "",
        overrides: [
            MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: true, body: "{}", contentType: "application/json")
        ],
        endpoints: [endpoint],
        removeOverride: { _ in
            removeCalls += 1
            return []
        },
        setErrorMessage: { _ in }
    )
    #expect(removeCalls == 0)
}

@MainActor
@Test(.timeLimit(.minutes(1))) func removeDisabledOverridesForOperationRemovesAllMatchingRows() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let disabledA = MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: "{}", contentType: "application/json")
    let disabledB = MockOverride(name: "op", path: "/p", method: .get, statusCode: 503, exampleId: "ex", isEnabled: false, body: "{\"error\":true}", contentType: "application/json")
    let enabled = MockOverride(name: "op", path: "/p", method: .get, statusCode: 201, exampleId: nil, isEnabled: true, body: "{}", contentType: "application/json")
    var removedKeys: [MockOverride] = []
    await store.removeDisabledOverridesForOperation(
        endpointItem: item,
        pathPrefix: "",
        overrides: [disabledA, disabledB, enabled],
        endpoints: [endpoint],
        removeOverride: { key in
            removedKeys.append(key)
            return [enabled]
        },
        setErrorMessage: { _ in }
    )
    #expect(removedKeys.count == 2)
    #expect(removedKeys.allSatisfy { !$0.isEnabled })
    #expect(removedKeys.map(\.statusCode).sorted() == [200, 503])
}

@MainActor
@Test(.timeLimit(.minutes(1))) func removeDisabledOverridesForOperationPropagatesRemoveErrors() async {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let disabled = MockOverride(name: "op", path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    var err: String?
    await store.removeDisabledOverridesForOperation(
        endpointItem: item,
        pathPrefix: "",
        overrides: [disabled],
        endpoints: [endpoint],
        removeOverride: { _ in throw TestAsyncError.kaboom },
        setErrorMessage: { err = $0 }
    )
    #expect(err == "kaboom")
}
