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

private let pathPrefix = OpenAPIPathPrefix.defaultMountPath

// MARK: resyncMockFromServer (plan §1c B1 / B3 / B4)

@Test func resyncB1ExactRowOverwritesDraftIncludingDisabled() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{\"spec\":1}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let stored = MockOverride(
        name: "listPets",
        path: "/pets",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: "{\"stored\":true}",
        contentType: "application/json"
    )
    var draft = OverrideDetailDraft(
        mock: MockOverride(
            name: "listPets",
            path: "/pets",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "ignored",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: true
    )
    draft.resyncMockFromServer(overrides: [stored], endpoints: [endpoint], pathPrefix: pathPrefix)
    #expect(draft.mock.isEnabled == false)
    #expect(draft.mock.statusCode == 200)
    #expect(draft.mock.body == "{\"stored\":true}")
}

@Test func resyncB3AdoptFirstEnabledWhenExactMissingAndDraftOn() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{\"a\":0}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let enabled201 = MockOverride(
        name: "listPets",
        path: "/pets",
        method: .get,
        statusCode: 201,
        exampleId: nil,
        isEnabled: true,
        body: "{\"created\":1}",
        contentType: "application/json"
    )
    var draft = OverrideDetailDraft(
        mock: MockOverride(
            name: "listPets",
            path: "/pets",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: nil,
            contentType: nil
        ),
        validationMessage: nil,
        isDirty: false
    )
    draft.resyncMockFromServer(overrides: [enabled201], endpoints: [endpoint], pathPrefix: pathPrefix)
    #expect(draft.mock.isEnabled == true)
    #expect(draft.mock.statusCode == 201)
    #expect(draft.mock.body == "{\"created\":1}")
}

@Test func resyncB4DraftOffAndNoStoredRowResetsToSpecDefault() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 418, contentType: "application/json", body: "{\"teapot\":1}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    var draft = OverrideDetailDraft(
        mock: MockOverride(
            name: "listPets",
            path: "/pets",
            method: .get,
            statusCode: 404,
            exampleId: "gone",
            isEnabled: false,
            body: "nope",
            contentType: "application/json"
        ),
        validationMessage: "x",
        isDirty: true
    )
    draft.resyncMockFromServer(overrides: [], endpoints: [endpoint], pathPrefix: pathPrefix)
    #expect(draft.mock.isEnabled == false)
    #expect(draft.mock.statusCode == 418)
    #expect(draft.mock.exampleId == nil)
    #expect(draft.mock.body == nil)
    #expect(draft.mock.contentType == nil)
}

@Test func resyncWhenDraftOnButNoOverridesResetsLikeB4() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    var draft = OverrideDetailDraft(
        mock: MockOverride(
            name: "listPets",
            path: "/pets",
            method: .get,
            statusCode: 200,
            exampleId: nil,
            isEnabled: true,
            body: "orphan",
            contentType: "application/json"
        ),
        validationMessage: nil,
        isDirty: false
    )
    draft.resyncMockFromServer(overrides: [], endpoints: [endpoint], pathPrefix: pathPrefix)
    #expect(draft.mock.isEnabled == false)
    #expect(draft.mock.statusCode == 200)
    #expect(draft.mock.body == nil)
}

@Test func resyncB3DoesNotRunWhenDraftOffEvenIfOtherEnabledExists() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{\"s\":1}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let enabled201 = MockOverride(
        name: "listPets",
        path: "/pets",
        method: .get,
        statusCode: 201,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    var draft = OverrideDetailDraft(
        mock: MockOverride(
            name: "listPets",
            path: "/pets",
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
    draft.resyncMockFromServer(overrides: [enabled201], endpoints: [endpoint], pathPrefix: pathPrefix)
    #expect(draft.mock.isEnabled == false)
    #expect(draft.mock.statusCode == 200)
    #expect(draft.mock.exampleId == nil)
}
