import Foundation
import HTTPTypes
import KawarimiCore
import Testing
@testable import KawarimiHenge

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
@Test func savePropagatesErrorViaSetter() async {
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
        setErrorMessage: { lastError = $0 }
    )
    #expect(lastError == "kaboom")
    #expect(store.detail?.isDirty == true)
}

@MainActor
@Test func saveEnabledClearsErrorThenSuccessUpdatesDraft() async {
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
        setErrorMessage: { steps.append($0) }
    )
    #expect(steps == [nil])
    #expect(store.detail?.isDirty == false)
}

/// After save, ``OverrideEditorStore/applyWithBody`` must resync from the list returned by `configureOverride` (post-fetch), not only merge the outbound payload — otherwise UI chips / primary state can stay on pre-save identity.
@MainActor
@Test func applyWithBodyFreshOverridesResyncAdoptsServerExampleId() async {
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
        setErrorMessage: { _ in }
    )
    #expect(store.detail?.mock.exampleId == "serverExample")
    #expect(store.detail?.isDirty == false)
}

@MainActor
@Test func applyWithBodyResyncKeepsCustom503Enabled() async {
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
        setErrorMessage: { _ in }
    )
    #expect(store.detail?.mock.statusCode == 503)
    #expect(store.detail?.mock.isEnabled == true)
    #expect(store.detail?.mock.exampleId == ex)
}

@MainActor
@Test func saveDisabledSendsBodyAndIsEnabledFalse() async {
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
        setErrorMessage: { steps.append($0) }
    )
    #expect(steps == [nil])
    #expect(store.detail?.isDirty == false)
    #expect(store.detail?.mock.isEnabled == false)
}

@MainActor
@Test func applyWithBodySkipsConfiguratorWhenDetailMissing() async {
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
        setErrorMessage: { _ in }
    )
    #expect(callCount == 0)
}

@MainActor
@Test func clearOverrideAndDisableMockRowPropagateConfiguratorErrors() async {
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
    await store.clearOverride(
        endpointItem: item,
        configureOverride: { _ in throw TestAsyncError.kaboom },
        setErrorMessage: { err = $0 }
    )
    #expect(err == "kaboom")

    err = nil
    await store.disableCurrentMockRow(
        endpointItem: item,
        pathPrefix: "/api",
        overrides: [],
        configureOverride: { _ in throw TestAsyncError.kaboom },
        removeOverride: { _ in [] },
        setErrorMessage: { err = $0 }
    )
    #expect(err == "kaboom")
}
