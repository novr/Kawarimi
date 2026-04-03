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

// MARK: Seed `OverrideEditorStore.detail` directly, then assert `@Observable` state after store methods

@MainActor
@Test func validateBodyUpdatesObservableDetailAfterPropertySeededDraft() {
    let store = OverrideEditorStore()
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "op",
            path: "/p",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "{",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: false
    )
    store.validateBody()
    #expect(store.detail?.validationMessage == EditorValidation.invalidJSONMessage)
    #expect(store.detail?.isDirty == false)
}

@MainActor
@Test func validateBodySetsValidMessageWhenDetailSeededWithValidJson() {
    let store = OverrideEditorStore()
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            path: "/p",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "{\"a\":1}",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: false
    )
    store.validateBody()
    #expect(store.detail?.validationMessage == EditorValidation.validJSONMessage)
}

@MainActor
@Test func markSavedCleanMutatesObservableDetailInPlace() {
    let store = OverrideEditorStore()
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            path: "/p",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "{}",
            contentType: "application/json"
        ),
        validationMessage: EditorValidation.validJSONMessage,
        isDirty: true
    )
    store.markSavedClean()
    #expect(store.detail?.isDirty == false)
    #expect(store.detail?.validationMessage == nil)
}

@MainActor
@Test func formatBodyUpdatesObservableDetailWhenSeeded() {
    let store = OverrideEditorStore()
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            path: "/p",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "{\"z\":1,\"a\":2}",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: false
    )
    store.formatBody()
    #expect(store.detail?.isDirty == true)
    #expect(store.detail?.validationMessage == EditorValidation.formattedMessage)
    #expect(store.detail?.mock.body?.contains("\"a\"") == true)
    #expect(store.detail?.mock.body?.contains("\"z\"") == true)
}

@MainActor
@Test func applyMockEditUpdatesObservableDetailWhenRowMatches() {
    let store = OverrideEditorStore()
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "getP",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "getP",
            path: "/p",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: false,
            body: nil,
            contentType: nil
        ),
        validationMessage: "x",
        isDirty: false
    )
    let incoming = MockOverride(
        name: "getP",
        path: "/p",
        method: .get,
        statusCode: 201,
        exampleId: "e1",
        isEnabled: true,
        body: "[]",
        contentType: "application/json"
    )
    store.applyMockEdit(from: item, newMock: incoming)
    #expect(store.detail?.mock.statusCode == 201)
    #expect(store.detail?.mock.exampleId == "e1")
    #expect(store.detail?.mock.isEnabled == true)
    #expect(store.detail?.isDirty == true)
    #expect(store.detail?.validationMessage == nil)
}

