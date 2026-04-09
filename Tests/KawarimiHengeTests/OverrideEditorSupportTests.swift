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

@Test func endpointFilterEmptyOrWhitespaceReturnsAllAndMatchesPathMethodOperationId() {
    let ep = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "listPets",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let single = [SpecEndpointItem(ep)]
    #expect(EndpointFilter.filter(single, searchText: "").map(\.id) == single.map(\.id))
    #expect(EndpointFilter.filter(single, searchText: "   ").map(\.id) == single.map(\.id))

    let a = FakeSpecEndpoint(path: "/api/v1/users", method: .get, operationId: "listUsers", responseList: [])
    let b = FakeSpecEndpoint(path: "/orders", method: .post, operationId: "createOrder", responseList: [])
    let items = [SpecEndpointItem(a), SpecEndpointItem(b)]
    #expect(EndpointFilter.filter(items, searchText: "users").map(\.id) == ["listUsers"])
    #expect(EndpointFilter.filter(items, searchText: "POST").map(\.id) == ["createOrder"])
    #expect(EndpointFilter.filter(items, searchText: "order").map(\.id) == ["createOrder"])
}

// MARK: - Save payload

@Test func savePayloadWhenDisabledOnSpecRowClearsBodyKeepsStatus() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "list",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
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
    let built = SavePayload.build(mock: mock, endpoint: endpoint)
    #expect(built.isEnabled == false)
    #expect(built.statusCode == 200)
    #expect(built.exampleId == nil)
    #expect(built.body == nil)
}

@Test func savePayloadWhenDisabledOnNonFirstSpecRowPreservesStatusCode() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .post,
        operationId: "create",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
            FakeSpecResponse(statusCode: 201, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil),
        ]
    )
    let mock = MockOverride(
        name: "create",
        path: "/pets",
        method: .post,
        statusCode: 201,
        exampleId: nil,
        isEnabled: false,
        body: nil,
        contentType: nil
    )
    let built = SavePayload.build(mock: mock, endpoint: endpoint)
    #expect(built.isEnabled == false)
    #expect(built.statusCode == 201)
    #expect(built.exampleId == nil)
    #expect(built.body == nil)
}

@Test func savePayloadWhenDisabledPreservesNamedExampleIdentity() {
    let endpoint = FakeSpecEndpoint(
        path: "/pets",
        method: .get,
        operationId: "list",
        responseList: [
            FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: "beta", summary: nil, description: nil),
        ]
    )
    let mock = MockOverride(
        name: "list",
        path: "/pets",
        method: .get,
        statusCode: 200,
        exampleId: "beta",
        isEnabled: false,
        body: nil,
        contentType: nil
    )
    let built = SavePayload.build(mock: mock, endpoint: endpoint)
    #expect(built.isEnabled == false)
    #expect(built.statusCode == 200)
    #expect(built.exampleId == "beta")
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
    let built = SavePayload.build(mock: mock, endpoint: endpoint)
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
    let plan = DisableMockPlanner.plan(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: "/api",
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
    let plan = DisableMockPlanner.plan(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: "/api",
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
    let plan = DisableMockPlanner.plan(
        mock: mock,
        endpoint: endpoint,
        rowKey: item.rowKey,
        pathPrefix: "/api",
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
    let mock = MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    let specOpt = ResponseChip(
        id: ResponseChip.specRowId,
        statusCode: -1,
        exampleId: nil,
        label: "Spec",
        isInactive: false
    )
    let selected = ResponseChips.chipIsSelected(
        option: specOpt,
        mock: mock,
        endpoint: endpoint
    )
    #expect(selected == true)
}

@Test func responseChipSpecWinsWhenDisabledStoredRowButDraftBodyCleared() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
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
    let mock = MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    let options = ResponseChips.buildChipOptions(
        mock: mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [stored],
        pathPrefix: "/api"
    )
    let specOpt = options.first { $0.isSpec }!
    let row200 = options.first { $0.statusCode == 200 && !$0.isSpec }!
    #expect(
        ResponseChips.chipIsSelected(
            option: specOpt,
            mock: mock,
            endpoint: endpoint
        )
    )
    #expect(
        ResponseChips.chipIsSelected(
            option: row200,
            mock: mock,
            endpoint: endpoint
        ) == false
    )
}

@Test func responseChipSpecNotSelectedWhenDraftIsUnsavedCustomStatus() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let item = SpecEndpointItem(endpoint)
    let storedCustom = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 503,
        exampleId: "scratch",
        isEnabled: false,
        body: "{}",
        contentType: "application/json"
    )
    let mock = MockOverride(
        path: "/p",
        method: .get,
        statusCode: 503,
        exampleId: "scratch",
        isEnabled: false,
        body: nil,
        contentType: nil
    )
    let options = ResponseChips.buildChipOptions(
        mock: mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [storedCustom],
        pathPrefix: "/api"
    )
    let specOpt = options.first { $0.isSpec }!
    let customChip = options.first { $0.statusCode == 503 && !$0.isSpec }!
    #expect(ResponseChips.chipIsSelected(option: specOpt, mock: mock, endpoint: endpoint) == false)
    #expect(ResponseChips.chipIsSelected(option: customChip, mock: mock, endpoint: endpoint))
}

@Test func responseChipStatusWinsWhenDisabledStoredRowAndDraftKeepsBody() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
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
    let mock = MockOverride(
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: "{\"k\":1}",
        contentType: "application/json"
    )
    let options = ResponseChips.buildChipOptions(
        mock: mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [stored],
        pathPrefix: "/api"
    )
    let specOpt = options.first { $0.isSpec }!
    let row200 = options.first { $0.statusCode == 200 && !$0.isSpec }!
    #expect(
        ResponseChips.chipIsSelected(
            option: specOpt,
            mock: mock,
            endpoint: endpoint
        ) == false
    )
    #expect(
        ResponseChips.chipIsSelected(
            option: row200,
            mock: mock,
            endpoint: endpoint
        )
    )
}

@Test func savePayloadSpecOnlySendsDisableEvenWhenStoredRowStillEnabled() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let serverRow = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{\"x\":1}",
        contentType: "application/json"
    )
    let mock = MockOverride(path: "/p", method: .get, statusCode: 200, exampleId: nil, isEnabled: false, body: nil, contentType: nil)
    #expect(serverRow.isEnabled)
    let built = SavePayload.build(mock: mock, endpoint: endpoint)
    #expect(built.isEnabled == false)
    #expect(built.body == nil)
    #expect(built.exampleId == nil)
    #expect(built.statusCode == 200)
}

@Test func savePayloadWhenMockOffDespiteStoredEnabledRowSendsDisable() {
    let endpoint = FakeSpecEndpoint(
        path: "/p",
        method: .get,
        operationId: "op",
        responseList: [FakeSpecResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    let serverRow = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{\"x\":1}",
        contentType: "application/json"
    )
    // Non–Spec-only draft (body not empty): previously `hasRow` forced `isEnabled` true and flipped Mock active after Save.
    let mock = MockOverride(
        name: "op",
        path: "/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: "{}",
        contentType: "application/json"
    )
    #expect(serverRow.isEnabled)
    let built = SavePayload.build(mock: mock, endpoint: endpoint)
    #expect(built.isEnabled == false)
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
    let specOpt = ResponseChip(
        id: ResponseChip.specRowId,
        statusCode: -1,
        exampleId: nil,
        label: "Spec",
        isInactive: false
    )
    ResponseChips.applyChipSelection(
        option: specOpt,
        mock: &mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [],
        pathPrefix: "/api"
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
    let rowOpt = ResponseChip(id: "200#__default", statusCode: 200, exampleId: nil, label: "200 OK", isInactive: true)
    ResponseChips.applyChipSelection(
        option: rowOpt,
        mock: &mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [stored],
        pathPrefix: "/api"
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
    let rowOpt = ResponseChip(id: "200#__default", statusCode: 200, exampleId: nil, label: "200 OK", isInactive: false)
    ResponseChips.applyChipSelection(
        option: rowOpt,
        mock: &mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [],
        pathPrefix: "/api"
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
    let opts = ResponseChips.buildChipOptions(
        mock: mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [],
        pathPrefix: "/api"
    )
    #expect(opts.count == 3)
    #expect(opts.first?.isSpec == true)
}

// MARK: - Spec template vs chip selection

@Test func responseChipSpecWinsWhenDisabledRowShowsTemplateBodyWithoutNumberedPin() {
    let specBody = "{\"message\":\"Hello from API\"}"
    let prettyBody =
        """
        {
          "message" : "Hello from API"
        }
        """
    let endpoint = FakeSpecEndpoint(
        path: "/api/greet",
        method: .get,
        operationId: "getGreeting",
        responseList: [
            FakeSpecResponse(
                statusCode: 200,
                contentType: "application/json",
                body: specBody,
                exampleId: nil,
                summary: nil,
                description: nil
            ),
        ]
    )
    let stored = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: nil,
        contentType: nil
    )
    let mock = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: prettyBody,
        contentType: "application/json"
    )
    let item = SpecEndpointItem(endpoint)
    let options = ResponseChips.buildChipOptions(
        mock: mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [stored],
        pathPrefix: "/api"
    )
    let specOpt = options.first { $0.isSpec }!
    let row200 = options.first { $0.statusCode == 200 && !$0.isSpec }!
    // No enabled mock + template matches spec row → highlight **Spec** (sidebar “Spec” aligns with detail).
    #expect(ResponseChips.chipIsSelected(option: specOpt, mock: mock, endpoint: endpoint))
    #expect(ResponseChips.chipIsSelected(option: row200, mock: mock, endpoint: endpoint) == false)
}

@Test func responseChip200WinsWhenNumberedChipPinnedAndTemplateBodyMatches() {
    let specBody = "{\"message\":\"Hello from API\"}"
    let endpoint = FakeSpecEndpoint(
        path: "/api/greet",
        method: .get,
        operationId: "getGreeting",
        responseList: [
            FakeSpecResponse(
                statusCode: 200,
                contentType: "application/json",
                body: specBody,
                exampleId: nil,
                summary: nil,
                description: nil
            ),
        ]
    )
    let mock = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: specBody,
        contentType: "application/json"
    )
    let item = SpecEndpointItem(endpoint)
    let options = ResponseChips.buildChipOptions(
        mock: mock,
        endpointItem: item,
        endpoint: endpoint,
        overrides: [],
        pathPrefix: "/api"
    )
    let specOpt = options.first { $0.isSpec }!
    let row200 = options.first { $0.statusCode == 200 && !$0.isSpec }!
    #expect(
        ResponseChips.chipIsSelected(
            option: specOpt,
            mock: mock,
            endpoint: endpoint,
            pinnedNumberedResponseChip: true
        ) == false
    )
    #expect(
        ResponseChips.chipIsSelected(
            option: row200,
            mock: mock,
            endpoint: endpoint,
            pinnedNumberedResponseChip: true
        )
    )
}

@Test func savePayloadSpecOnlyWhenDraftShowsTemplateJson() {
    let specBody = "{\"message\":\"Hello from API\"}"
    let endpoint = FakeSpecEndpoint(
        path: "/greet",
        method: .get,
        operationId: "getGreeting",
        responseList: [
            FakeSpecResponse(
                statusCode: 200,
                contentType: "application/json",
                body: specBody,
                exampleId: nil,
                summary: nil,
                description: nil
            ),
        ]
    )
    let mock = MockOverride(
        name: "getGreeting",
        path: "/greet",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: false,
        body: specBody,
        contentType: "application/json"
    )
    let built = SavePayload.build(mock: mock, endpoint: endpoint)
    #expect(built.isEnabled == false)
    #expect(built.body == nil)
}

// MARK: - Exclusive enabled row (configure)

@Test func peerShouldDisableWhenDifferentStatusSameOperation() {
    let saved = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let peer = MockOverride(
        name: "getGreeting",
        path: "/api/greet",
        method: .get,
        statusCode: 503,
        exampleId: "105e2d2c",
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    #expect(
        OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow(
            saved: saved,
            peer: peer,
            pathPrefix: "/api"
        )
    )
}

@Test func peerShouldDisableWhenSameStatusDifferentExampleId() {
    let saved = MockOverride(
        name: "op",
        path: "/api/p",
        method: .get,
        statusCode: 200,
        exampleId: "alpha",
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let peer = MockOverride(
        name: "op",
        path: "/api/p",
        method: .get,
        statusCode: 200,
        exampleId: "beta",
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    #expect(
        OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow(
            saved: saved,
            peer: peer,
            pathPrefix: "/api"
        )
    )
}

@Test func peerShouldNotDisableSameIdentityRow() {
    let row = MockOverride(
        name: "op",
        path: "/api/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    #expect(
        !OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow(
            saved: row,
            peer: row,
            pathPrefix: "/api"
        )
    )
}

@Test func peerShouldNotDisableWhenPeerOff() {
    let saved = MockOverride(
        name: "op",
        path: "/api/p",
        method: .get,
        statusCode: 200,
        exampleId: nil,
        isEnabled: true,
        body: "{}",
        contentType: "application/json"
    )
    let peer = MockOverride(
        name: "op",
        path: "/api/p",
        method: .get,
        statusCode: 503,
        exampleId: nil,
        isEnabled: false,
        body: "{}",
        contentType: "application/json"
    )
    #expect(
        !OverrideListQueries.peerShouldBeDisabledWhenSavingEnabledRow(
            saved: saved,
            peer: peer,
            pathPrefix: "/api"
        )
    )
}
