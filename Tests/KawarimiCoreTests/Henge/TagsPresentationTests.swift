import HTTPTypes
import KawarimiCore
import Testing
@testable import KawarimiHengeCore

private struct FakeSpecEndpoint: SpecEndpointProviding {
    var path: String
    var method: HTTPRequest.Method
    var operationId: String
    var tags: [String]?
    var responseList: [any SpecMockResponseProviding] = []
}

@Test func tagsPresentationReturnsNilWhenAbsentOrEmpty() {
    let noTags = FakeSpecEndpoint(path: "/", method: .get, operationId: "a", tags: nil)
    #expect(TagsPresentation.displayTags(for: noTags) == nil)

    let empty = FakeSpecEndpoint(path: "/", method: .get, operationId: "b", tags: [])
    #expect(TagsPresentation.displayTags(for: empty) == nil)
}

@Test func tagsPresentationReturnsTagsWhenPresent() {
    let endpoint = FakeSpecEndpoint(path: "/pets", method: .get, operationId: "list", tags: ["Items", "Pets"])
    #expect(TagsPresentation.displayTags(for: endpoint) == ["Items", "Pets"])
}

@Test func endpointFilterMatchesTagText() {
    let endpoint = FakeSpecEndpoint(path: "/x", method: .get, operationId: "op", tags: ["Greetings"])
    let items = [SpecEndpointItem(endpoint)]
    #expect(EndpointFilter.filter(items, searchText: "greet").map(\.id) == ["op"])
    #expect(EndpointFilter.filter(items, searchText: "orders").isEmpty)
}
