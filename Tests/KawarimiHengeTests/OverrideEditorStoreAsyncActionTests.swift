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

// MARK: ``OverrideEditorStore/applyWithBody`` (async + injected `configureOverride`)

@MainActor
@Test func applyWithBodyPropagatesErrorViaSetter() async {
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
@Test func applyWithBodyClearsErrorThenSuccessUpdatesDraft() async {
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
        },
        setErrorMessage: { steps.append($0) }
    )
    #expect(steps == [nil])
    #expect(store.detail?.isDirty == false)
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
        removeOverride: { _ in },
        setErrorMessage: { err = $0 }
    )
    #expect(err == "kaboom")
}
