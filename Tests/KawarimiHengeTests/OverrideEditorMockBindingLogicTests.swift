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

// MARK: `validationMessageBinding` set → ``OverrideEditorStore/setDetailValidationMessage``

@MainActor
@Test func setDetailValidationMessageUpdatesObservableDetail() {
    let store = OverrideEditorStore()
    store.detail = OverrideDetailDraft(
        mock: MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil),
        validationMessage: nil,
        isDirty: false
    )
    store.setDetailValidationMessage("edited")
    #expect(store.detail?.validationMessage == "edited")
    store.setDetailValidationMessage(nil)
    #expect(store.detail?.validationMessage == nil)
}

// MARK: `mockBinding` set → ``OverrideEditorStore/applyMockEdit(from:newMock:)``

@MainActor
@Test func applyMockEditNoOpWhenRowAndOperationMismatch() {
    let store = OverrideEditorStore()
    let epB = FakeSpecEndpoint(
        path: "/b",
        method: .get,
        operationId: "opB",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let itemB = SpecEndpointItem(epB)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(name: "opA", path: "/a", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil),
        validationMessage: nil,
        isDirty: false
    )
    let before = store.detail?.mock.statusCode
    store.applyMockEdit(
        from: itemB,
        newMock: MockOverride(name: "opB", path: "/b", method: .get, statusCode: 503, exampleId: nil, isEnabled: true, body: "{}", contentType: nil)
    )
    #expect(store.detail?.mock.statusCode == before)
    #expect(store.detail?.isDirty == false)
}

@MainActor
@Test func applyMockEditSameOperationIdRealignsPathWhenSpecPathDiffers() {
    let store = OverrideEditorStore()
    let specEndpoint = FakeSpecEndpoint(
        path: "/spec/pets",
        method: .get,
        operationId: "listPets",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(specEndpoint)
    store.detail = OverrideDetailDraft(
        mock: MockOverride(
            name: "listPets",
            path: "/api/pets",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "{}",
            contentType: "application/json"
        ),
        validationMessage: "keep",
        isDirty: false
    )
    store.applyMockEdit(
        from: item,
        newMock: MockOverride(
            name: "listPets",
            path: "/api/pets",
            method: .get,
            statusCode: 201,
            exampleId: "n",
            isEnabled: true,
            body: "[]",
            contentType: "application/json"
        )
    )
    #expect(store.detail?.mock.path == "/spec/pets")
    #expect(store.detail?.mock.statusCode == 201)
    #expect(store.detail?.mock.exampleId == "n")
    #expect(store.detail?.isDirty == true)
    #expect(store.detail?.validationMessage == nil)
}
