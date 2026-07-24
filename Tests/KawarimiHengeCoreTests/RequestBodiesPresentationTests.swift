import Foundation
import HTTPTypes
import KawarimiCore
import KawarimiHengeCore
import Testing

private struct FakeResponse: SpecMockResponseProviding {
    var statusCode: Int
    var contentType: String
    var body: String
    var exampleId: String?
    var summary: String?
    var description: String?
}

private struct FakeEndpoint: SpecEndpointProviding {
    var path: String
    var method: HTTPRequest.Method
    var operationId: String
    var requestBodies: [SpecRequestBody]?
    var responseList: [any SpecMockResponseProviding]
}

@Test func requestBodiesPresentationNilWhenAbsent() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: nil,
        responseList: [FakeResponse(statusCode: 201, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    #expect(RequestBodiesPresentation.displayLines(for: endpoint) == nil)
}

@Test func requestBodiesPresentationNilWhenEmptyArray() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: [],
        responseList: []
    )
    #expect(RequestBodiesPresentation.displayLines(for: endpoint) == nil)
}

@Test func requestBodiesPresentationOmitsWhitespaceOnlyExampleId() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: [
            SpecRequestBody(required: true, contentType: "application/json", body: "{}", exampleId: "  "),
        ],
        responseList: []
    )
    #expect(RequestBodiesPresentation.displayLines(for: endpoint) == [
        "application/json · required",
    ])
}

@Test func requestBodiesPresentationFormatsLines() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: [
            SpecRequestBody(
                required: true,
                contentType: "application/json",
                body: #"{"name":""}"#,
                exampleId: "minimal",
                description: "Create payload"
            ),
            SpecRequestBody(required: false, contentType: "application/json", body: #"{"name":"x"}"#),
        ],
        responseList: []
    )
    #expect(RequestBodiesPresentation.displayLines(for: endpoint) == [
        "application/json · required · minimal · Create payload",
        "application/json · optional",
    ])
}
