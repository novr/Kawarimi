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
    #expect(items[0].caseItems[0].id == rowId.rawValue)
    let rowKey = items[0].caseItems[0].endpointRowKey
    #expect(rowKey?.method == HTTPRequest.Method.get)
    #expect(rowKey?.path == "/api/greet")
}

@MainActor
@Test func selectOverrideOpensStoredRowMatchingRowIdAndPreservesRowId() {
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
    let ok = store.selectOverride(
        rowId: rowId,
        pathPrefix: "/api",
        endpoints: endpoints,
        overrides: overrides
    )
    #expect(ok)
    #expect(store.detail?.mock.rowId == rowId)
    #expect(store.detail?.mock.exampleId == "formal")
    #expect(store.detail?.mock.body == "{\"message\":\"Good day\"}")
    #expect(store.detail?.mock.isEnabled == false)
    #expect(store.detail?.pinnedNumberedResponseChip == true)
    #expect(store.selectedRowKey?.path == "/api/greet")
    #expect(store.selectedRowKey?.method == .get)
}

@MainActor
@Test func selectOverrideDoesNotFallBackToPrimaryWhenChipWouldMiss() {
    // Disabled ghost-like custom status not listed as a named OpenAPI example chip pair —
    // still must open THIS rowId, not the enabled primary on the same endpoint.
    let targetRowId = MockOverrideRowID(rawValue: "00000000-0000-0000-0000-000000000099")!
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
            rowId: targetRowId,
            path: "/api/greet",
            method: .get,
            statusCode: 503,
            exampleId: nil,
            isEnabled: false,
            body: "{\"error\":\"down\"}",
            contentType: "application/json"
        ),
    ]
    let store = OverrideEditorStore()
    #expect(
        store.selectOverride(
            rowId: targetRowId,
            pathPrefix: "/api",
            endpoints: endpoints,
            overrides: overrides
        )
    )
    #expect(store.detail?.mock.rowId == targetRowId)
    #expect(store.detail?.mock.statusCode == 503)
    #expect(store.detail?.mock.isEnabled == false)
}

@MainActor
@Test func selectOverrideReturnsFalseWhenRowIdMissing() {
    let store = OverrideEditorStore()
    let missing = MockOverrideRowID(rawValue: "00000000-0000-0000-0000-0000000000ff")!
    let ok = store.selectOverride(
        rowId: missing,
        pathPrefix: "/api",
        endpoints: [
            FakeSpecEndpoint(
                path: "/api/greet",
                method: .get,
                operationId: "getGreeting",
                responseList: [
                    FakeSpecResponse(
                        statusCode: 200,
                        contentType: "application/json",
                        body: "{}",
                        exampleId: nil,
                        summary: nil,
                        description: nil
                    ),
                ]
            ),
        ],
        overrides: []
    )
    #expect(!ok)
    #expect(store.detail == nil)
    #expect(
        !ScenarioBrowserPresentation.canNavigate(
            rowId: missing,
            pathPrefix: "/api",
            endpoints: [
                FakeSpecEndpoint(
                    path: "/api/greet",
                    method: .get,
                    operationId: "getGreeting",
                    responseList: []
                ),
            ],
            overrides: []
        )
    )
}
