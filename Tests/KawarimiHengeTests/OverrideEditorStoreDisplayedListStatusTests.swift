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

private let pathPrefix = "/api"

// MARK: displayedListStatus — server-primary list (ignores open detail for same-row edits)

@MainActor
@Test func displayedListStatusA1NoDetailUsesPrimaryEnabledStatusCode() {
    let store = OverrideEditorStore()
    store.detail = nil
    let endpoint = FakeSpecEndpoint(
        path: "/a",
        method: .get,
        operationId: "getA",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let rowKey = EndpointRowKey(endpoint)
    let ov = MockOverride(
        name: "getA",
        path: "/a",
        method: .get,
        statusCode: 503,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let code = store.displayedListStatus(for: rowKey, operationId: endpoint.operationId, pathPrefix: pathPrefix, overrides: [ov])
    #expect(code == 503)
}

@MainActor
@Test func displayedListStatusA1NoDetailReturnsMinusOneWhenNoEnabledOverride() {
    let store = OverrideEditorStore()
    store.detail = nil
    let endpoint = FakeSpecEndpoint(
        path: "/a",
        method: .get,
        operationId: "getA",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let rowKey = EndpointRowKey(endpoint)
    let code = store.displayedListStatus(for: rowKey, operationId: endpoint.operationId, pathPrefix: pathPrefix, overrides: [])
    #expect(code == -1)
}

@MainActor
/// List status is **always** the server primary enabled row; the open detail selection does not drive the sidebar.
@Test func displayedListStatusA2IgnoresSelectedDraftUsesPrimaryEnabled() {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/a",
        method: .get,
        operationId: "getA",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let rowKey = EndpointRowKey(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "getA",
            path: "/a",
            method: .get,
            statusCode: 418,
            exampleId: nil,
            isEnabled: true,
            body: "{}",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: false
    )
    let otherRowEnabled = MockOverride(
        name: "getA",
        path: "/a",
        method: .get,
        statusCode: 500,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let code = store.displayedListStatus(for: rowKey, operationId: endpoint.operationId, pathPrefix: pathPrefix, overrides: [otherRowEnabled])
    #expect(code == 500)
}

@MainActor
@Test func displayedListStatusA3SelectedRowDisabledFallsBackToPrimaryEnabled() {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/a",
        method: .get,
        operationId: "getA",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let rowKey = EndpointRowKey(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "getA",
            path: "/a",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: false,
            body: nil,
            contentType: nil
        ),
        validationMessage: nil,
        isDirty: false
    )
    let enabled = MockOverride(
        name: "getA",
        path: "/a",
        method: .get,
        statusCode: 502,
        exampleId: "alt",
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let code = store.displayedListStatus(for: rowKey, operationId: endpoint.operationId, pathPrefix: pathPrefix, overrides: [enabled])
    #expect(code == 502)
}

@MainActor
@Test func displayedListStatusA3SelectedRowDisabledReturnsMinusOneWithoutEnabledOverride() {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/a",
        method: .get,
        operationId: "getA",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let rowKey = EndpointRowKey(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "getA",
            path: "/a",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: false,
            body: nil,
            contentType: nil
        ),
        validationMessage: nil,
        isDirty: false
    )
    let code = store.displayedListStatus(for: rowKey, operationId: endpoint.operationId, pathPrefix: pathPrefix, overrides: [])
    #expect(code == -1)
}

@MainActor
@Test func displayedListStatusOtherRowIgnoresDraftForDifferentEndpoint() {
    let store = OverrideEditorStore()
    let other = FakeSpecEndpoint(
        path: "/other",
        method: .get,
        operationId: "oth",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "sel",
            path: "/selected",
            method: .get,
            statusCode: 404,
            exampleId: nil,
            isEnabled: true,
            body: "{}",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: false
    )
    let otherKey = EndpointRowKey(other)
    let ov = MockOverride(
        name: "oth",
        path: "/other",
        method: .get,
        statusCode: 201,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let code = store.displayedListStatus(for: otherKey, operationId: other.operationId, pathPrefix: pathPrefix, overrides: [ov])
    #expect(code == 201)
}
