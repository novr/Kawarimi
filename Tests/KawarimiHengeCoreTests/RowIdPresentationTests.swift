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

@Test func rowIdPresentationCopyTextReturnsRawValue() {
    let rowId = MockOverrideRowID.generate()
    #expect(RowIdPresentation.copyText(for: rowId) == rowId.rawValue)
}

@Test func rowIdPresentationDisplayRowIdReturnsTextForStoredRow() {
    let rowId = MockOverrideRowID.generate()
    let endpoint = FakeSpecEndpoint(
        path: "/api/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let item = SpecEndpointItem(endpoint)
    let stored = MockOverride(
        name: "listPets",
        rowId: rowId,
        path: "/api/pets",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let mock = MockOverride(
        path: "/api/pets",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let text = RowIdPresentation.displayRowId(
        mock: mock,
        rowKey: item.rowKey,
        endpoint: endpoint,
        operationId: "listPets",
        pathPrefix: "/api",
        in: [stored]
    )
    #expect(text == rowId.rawValue)
}

@Test func rowIdPresentationDisplayRowIdReturnsNilWithoutStoredRow() {
    let endpoint = FakeSpecEndpoint(
        path: "/api/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let item = SpecEndpointItem(endpoint)
    let mock = MockOverride(
        path: "/api/pets",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    #expect(
        RowIdPresentation.displayRowId(
            mock: mock,
            rowKey: item.rowKey,
            endpoint: endpoint,
            operationId: "listPets",
            pathPrefix: "/api",
            in: []
        ) == nil
    )
}

@Test func rowIdPresentationDisplayRowIdReturnsNilForLegacyRowWithoutRowId() {
    let endpoint = FakeSpecEndpoint(
        path: "/api/pets",
        method: .get,
        operationId: "listPets",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let item = SpecEndpointItem(endpoint)
    let stored = MockOverride(
        name: "listPets",
        path: "/api/pets",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let mock = MockOverride(
        path: "/api/pets",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    #expect(
        RowIdPresentation.displayRowId(
            mock: mock,
            rowKey: item.rowKey,
            endpoint: endpoint,
            operationId: "listPets",
            pathPrefix: "/api",
            in: [stored]
        ) == nil
    )
}
