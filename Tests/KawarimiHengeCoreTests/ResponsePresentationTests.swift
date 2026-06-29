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

@Test func responsePresentationResolvesSelectedChipByIndex() {
    let responses: [any SpecMockResponseProviding] = [
        FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: "a", summary: "OK", description: "Success body"),
        FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: "b", summary: "Alt", description: nil),
    ]
    let endpoint = FakeSpecEndpoint(path: "/", method: .get, operationId: "op", responseList: responses)
    let chip = ResponseChip(
        id: "200#b",
        statusCode: 200,
        exampleId: "b",
        label: "200 · b",
        isInactive: false,
        specResponseListIndex: 1
    )
    let options = [
        ResponseChip(id: ResponseChip.specRowId, statusCode: -1, exampleId: nil, label: "Spec", isInactive: false),
        chip,
    ]
    let mock = MockOverride(
        name: "op",
        path: "/",
        method: .get,
        statusCode: 200,
        exampleId: "b",
        isEnabled: true
    )
    let doc = ResponsePresentation.documentationForSelection(
        options: options,
        mock: mock,
        endpoint: endpoint,
        pinnedNumberedResponseChip: false
    )
    #expect(doc?.summary == "Alt")
    #expect(doc?.description == nil)
}

@Test func responsePresentationReturnsNilForSpecChip() {
    let endpoint = FakeSpecEndpoint(
        path: "/",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: "S", description: "D")]
    )
    let options = [ResponseChip(id: ResponseChip.specRowId, statusCode: -1, exampleId: nil, label: "Spec", isInactive: false)]
    let mock = MockOverride(
        name: "op",
        path: "/",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false
    )
    #expect(
        ResponsePresentation.documentationForSelection(
            options: options,
            mock: mock,
            endpoint: endpoint,
            pinnedNumberedResponseChip: false
        ) == nil
    )
}
