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

// MARK: - Endpoint filter

@Test func endpointFilterEmptyQueryReturnsAll() {
    let ep = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "listPets",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let items = [SpecEndpointItem(ep)]
    #expect(OverrideEndpointFilter.filter(items, searchText: "").map(\.id) == items.map(\.id))
    #expect(OverrideEndpointFilter.filter(items, searchText: "   ").map(\.id) == items.map(\.id))
}

@Test func endpointFilterMatchesPathMethodOperationId() {
    let a = FakeSpecEndpoint(path: "/api/v1/users", method: .get, operationId: "listUsers", responseList: [])
    let b = FakeSpecEndpoint(path: "/orders", method: .post, operationId: "createOrder", responseList: [])
    let items = [SpecEndpointItem(a), SpecEndpointItem(b)]
    #expect(OverrideEndpointFilter.filter(items, searchText: "users").map(\.id) == ["listUsers"])
    #expect(OverrideEndpointFilter.filter(items, searchText: "POST").map(\.id) == ["createOrder"])
    #expect(OverrideEndpointFilter.filter(items, searchText: "order").map(\.id) == ["createOrder"])
}

// MARK: - Save payload

@Test func savePayloadWhenDisabledOnSpecRowSendsDefaultStatusAndClearsExample() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "list",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let item = SpecEndpointItem(endpoint)
    let mock = MockOverride(
        name: "list",
        path: "/pets",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: "{ \"a\": 1 }",
        contentType: "application/json"
    )
    let built = OverrideSavePayloadBuilder.build(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: OpenAPIPathPrefix.defaultMountPath,
        overrides: []
    )
    #expect(built.isEnabled == false)
    #expect(built.statusCode == 200)
    #expect(built.exampleId == nil)
    #expect(built.body == nil)
}

@Test func savePayloadWhenEnabledPreservesStatusExampleAndBody() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "list",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let item = SpecEndpointItem(endpoint)
    let mock = MockOverride(
        name: "list",
        path: "/pets",
        method: .get,
        statusCode: 200,
        exampleId: "beta",
        isEnabled: true,
        body: "{ }",
        contentType: "application/json"
    )
    let built = OverrideSavePayloadBuilder.build(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: OpenAPIPathPrefix.defaultMountPath,
        overrides: []
    )
    #expect(built.isEnabled == true)
    #expect(built.statusCode == 200)
    #expect(built.exampleId == "beta")
    #expect(built.body == "{ }")
}

// MARK: - Disable row planner

@Test func disablePlannerWhenActiveConfiguresDisable() {
    let endpoint = FakeSpecEndpoint(
        path: "/x",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let mock = MockOverride(path: "/x", method: .get, statusCode: 200, exampleId: nil, isEnabled: true, body: "{}", contentType: "application/json")
    let plan = OverrideDisableMockRowPlanner.plan(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: OpenAPIPathPrefix.defaultMountPath,
        overrides: []
    )
    guard case let .configureDisable(payload) = plan else {
        Issue.record("expected configureDisable")
        return
    }
    #expect(payload.isEnabled == false)
    #expect(payload.statusCode == 200)
}

@Test func disablePlannerWhenInactiveWithStoredRowRemoves() {
    let endpoint = FakeSpecEndpoint(
        path: "/x",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let stored = MockOverride(
        name: "op",
        path: "/x",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: "{}",
        contentType: "application/json"
    )
    let mock = stored
    let plan = OverrideDisableMockRowPlanner.plan(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: OpenAPIPathPrefix.defaultMountPath,
        overrides: [stored]
    )
    guard case let .removeThenReset(removeKey, cleared) = plan else {
        Issue.record("expected removeThenReset")
        return
    }
    #expect(removeKey.statusCode == 200)
    #expect(cleared.isEnabled == false)
    #expect(cleared.statusCode == 200)
    #expect(cleared.exampleId == nil)
}

@Test func disablePlannerWhenInactiveWithoutRowIsNoOp() {
    let endpoint = FakeSpecEndpoint(
        path: "/x",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let mock = MockOverride(path: "/x", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    let plan = OverrideDisableMockRowPlanner.plan(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: OpenAPIPathPrefix.defaultMountPath,
        overrides: []
    )
    guard case .none = plan else {
        Issue.record("expected none")
        return
    }
}

// MARK: - Response chips

@Test func responseChipSpecOptionSelectedWhenMockOffAndNoStoredRow() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let mock = MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    let specOpt = MockResponseStatusChipOption(
        id: MockResponseStatusChipOption.specRowId,
        statusCode: -1,
        exampleId: nil,
        label: "Spec",
        isInactive: false
    )
    let selected = OverrideResponseChipLogic.chipIsSelected(
        option: specOpt,
        mock: mock,
        rowKey: item.rowKey,
        operationId: endpoint.operationId,
        pathPrefix: OpenAPIPathPrefix.defaultMountPath,
        overrides: []
    )
    #expect(selected == true)
}

@Test func applyChipSpecClearsMock() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    var mock = MockOverride(path: "/p", method: .get, statusCode: 404, exampleId: "x", isEnabled: true, body: "{}", contentType: "application/json")
    let specOpt = MockResponseStatusChipOption(
        id: MockResponseStatusChipOption.specRowId,
        statusCode: -1,
        exampleId: nil,
        label: "Spec",
        isInactive: false
    )
    OverrideResponseChipLogic.applyChipSelection(
        option: specOpt,
        mock: &mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [],
        pathPrefix: OpenAPIPathPrefix.defaultMountPath
    )
    #expect(mock.isEnabled == false)
    #expect(mock.statusCode == 200)
    #expect(mock.exampleId == nil)
    #expect(mock.body == nil)
}

@Test func applyChipWithStoredRowCopiesStored() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{\"s\":true}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let stored = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: "{\"k\":1}",
        contentType: "application/json"
    )
    var mock = MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: true, body: nil, contentType: nil)
    let rowOpt = MockResponseStatusChipOption(id: "200#__default", statusCode: 200, exampleId: nil, label: "200 OK", isInactive: true)
    OverrideResponseChipLogic.applyChipSelection(
        option: rowOpt,
        mock: &mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [stored],
        pathPrefix: OpenAPIPathPrefix.defaultMountPath
    )
    #expect(mock.isEnabled == false)
    #expect(mock.body == "{\"k\":1}")
}

@Test func applyChipWithoutStoredEnablesAndSeedsFromSpec() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{\"s\":true}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    var mock = MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    let rowOpt = MockResponseStatusChipOption(id: "200#__default", statusCode: 200, exampleId: nil, label: "200 OK", isInactive: false)
    OverrideResponseChipLogic.applyChipSelection(
        option: rowOpt,
        mock: &mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [],
        pathPrefix: OpenAPIPathPrefix.defaultMountPath
    )
    #expect(mock.isEnabled == true)
    #expect(mock.statusCode == 200)
    #expect(mock.body == "{\"s\":true}")
}

@Test func chipOptionsIncludeSpecAndSpecRows() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: "named", summary: nil, description: nil),
        ]
    )
    let item = SpecEndpointItem(endpoint)
    let mock = MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    let opts = OverrideResponseChipLogic.buildChipOptions(
        mock: mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [],
        pathPrefix: OpenAPIPathPrefix.defaultMountPath
    )
    #expect(opts.count == 3)
    #expect(opts.first?.isSpec == true)
}
