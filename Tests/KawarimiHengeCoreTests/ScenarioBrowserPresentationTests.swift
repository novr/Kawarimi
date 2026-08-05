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

@Test func scenarioBrowserPresentationBuildsEndpointRowKeyFromCaseEndpoint() {
    let rowId = MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!
    let scenario = KawarimiScenario(
        scenarioId: "greet",
        initial: "success",
        cases: [
            KawarimiScenarioCase(
                kawarimiId: "success",
                next: "formal",
                rowId: rowId,
                endpoint: KawarimiScenarioEndpoint(method: "GET", path: "/api/greet")
            ),
        ]
    )
    let items = ScenarioBrowserPresentation.items(from: [scenario])
    #expect(items.count == 1)
    #expect(items[0].caseItems.count == 1)
    let rowKey = items[0].caseItems[0].endpointRowKey
    #expect(rowKey?.method == HTTPRequest.Method.get)
    #expect(rowKey?.path == "/api/greet")
}

@MainActor
@Test func selectOverrideOpensStoredRowMatchingRowId() {
    let rowId = MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000002")!
    let endpoints: [any SpecEndpointProviding] = [
        FakeSpecEndpoint(
            path: "/api/greet",
            method: .get,
            operationId: "getGreeting",
            responseList: [
                FakeSpecResponse(
                    statusCode: 200,
                    contentType: "application/json",
                    body: "{}",
                    exampleId: "success",
                    summary: nil,
                    description: nil
                ),
                FakeSpecResponse(
                    statusCode: 200,
                    contentType: "application/json",
                    body: "{}",
                    exampleId: "formal",
                    summary: nil,
                    description: nil
                ),
            ]
        ),
    ]
    let overrides = [
        MockOverride(
            name: "getGreeting",
            rowId: MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000001")!,
            path: "/api/greet",
            method: .get,
            statusCode: 200,
            exampleId: "success",
            isEnabled: true,
            body: "{\"message\":\"Hello\"}",
            contentType: "application/json"
        ),
        MockOverride(
            name: "getGreeting",
            rowId: rowId,
            path: "/api/greet",
            method: .get,
            statusCode: 200,
            exampleId: "formal",
            isEnabled: false,
            body: "{\"message\":\"Good day\"}",
            contentType: "application/json"
        ),
    ]
    let store = OverrideEditorStore()
    store.selectOverride(
        rowId: rowId,
        pathPrefix: "/api",
        endpoints: endpoints,
        overrides: overrides
    )
    #expect(store.detail?.mock.exampleId == "formal")
    #expect(store.detail?.mock.isEnabled == false)
    #expect(store.detail?.pinnedNumberedResponseChip == true)
    #expect(store.selectedRowKey?.path == "/api/greet")
    #expect(store.selectedRowKey?.method == .get)
}
