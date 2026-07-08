import Foundation
import HTTPTypes
import KawarimiCore
import KawarimiHengeCore
import Testing

private struct FakeEndpoint: SpecEndpointProviding {
    var path: String
    var method: HTTPRequest.Method
    var operationId: String
    var parameters: [SpecParameter]?
    var responseList: [any SpecMockResponseProviding]
}

private struct FakeResponse: SpecMockResponseProviding {
    var statusCode: Int
    var contentType: String
    var body: String
    var exampleId: String?
    var summary: String?
    var description: String?
}

@Test(.timeLimit(.minutes(1))) func parametersPresentationNilWhenAbsent() {
    let endpoint = FakeEndpoint(
        path: "/",
        method: .get,
        operationId: "op",
        parameters: nil,
        responseList: [FakeResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    #expect(ParametersPresentation.displayLines(for: endpoint) == nil)
}

@Test(.timeLimit(.minutes(1))) func parametersPresentationFormatsLines() {
    let endpoint = FakeEndpoint(
        path: "/items/{id}",
        method: .get,
        operationId: "getItem",
        parameters: [
            SpecParameter(location: .path, name: "id", required: true, schemaType: "string"),
            SpecParameter(location: .query, name: "name", required: false, schemaType: "string"),
        ],
        responseList: [FakeResponse(statusCode: 200, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    #expect(ParametersPresentation.displayLines(for: endpoint) == [
        "path · id · string · required",
        "query · name · string · optional",
    ])
}
