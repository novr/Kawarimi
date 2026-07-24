import Foundation
import HTTPTypes
import KawarimiCore
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

@Test func preferredRequestBodyNilWhenAbsent() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: nil,
        responseList: [FakeResponse(statusCode: 201, contentType: "application/json", body: "{}", exampleId: nil, summary: nil, description: nil)]
    )
    #expect(SpecRequestBodySelection.preferredRequestBody(for: endpoint) == nil)
    #expect(SpecRequestBodySelection.defaultJSONBodyText(for: endpoint) == "{}")
}

@Test func preferredRequestBodyNilWhenEmptyArray() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: [],
        responseList: []
    )
    #expect(SpecRequestBodySelection.preferredRequestBody(for: endpoint) == nil)
    #expect(SpecRequestBodySelection.defaultJSONBodyText(for: endpoint) == "{}")
}

@Test func defaultJSONBodyTextUsesEmptyObjectWhenBodyBlank() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: [
            SpecRequestBody(required: true, contentType: "application/json", body: "   "),
        ],
        responseList: []
    )
    #expect(SpecRequestBodySelection.defaultJSONBodyText(for: endpoint) == "{}")
}

@Test func preferredRequestBodyPrefersExampleIdNilRow() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: [
            SpecRequestBody(required: true, contentType: "application/json", body: #"{"named":true}"#, exampleId: "named"),
            SpecRequestBody(required: true, contentType: "application/json", body: #"{"default":true}"#),
        ],
        responseList: []
    )
    let preferred = SpecRequestBodySelection.preferredRequestBody(for: endpoint)
    #expect(preferred?.body == #"{"default":true}"#)
    #expect(SpecRequestBodySelection.defaultJSONBodyText(for: endpoint) == #"{"default":true}"#)
}

@Test func preferredRequestBodyUsesFirstWhenAllNamed() {
    let endpoint = FakeEndpoint(
        path: "/items",
        method: .post,
        operationId: "createItem",
        requestBodies: [
            SpecRequestBody(required: true, contentType: "application/json", body: #"{"first":1}"#, exampleId: "first"),
            SpecRequestBody(required: false, contentType: "application/json", body: #"{"second":2}"#, exampleId: "second"),
        ],
        responseList: []
    )
    let preferred = SpecRequestBodySelection.preferredRequestBody(for: endpoint)
    #expect(preferred?.body == #"{"first":1}"#)
}

@Test func hengeSpecSnapshotEndpointUsesSelectionHelper() throws {
    let json = """
    {
      "meta": {
        "title": "T",
        "version": "1",
        "serverURL": "https://example.com/api",
        "apiPathPrefix": "/api"
      },
      "endpoints": [
        {
          "path": "/api/items",
          "method": "POST",
          "operationId": "createItem",
          "responses": [],
          "requestBodies": [
            {
              "required": true,
              "contentType": "application/json",
              "body": "{\\"name\\":\\"\\"}",
              "description": "Create payload"
            }
          ]
        }
      ]
    }
    """
    let snapshot = try JSONDecoder().decode(HengeSpecSnapshot.self, from: Data(json.utf8))
    let endpoint = try #require(snapshot.endpoints.first)
    #expect(SpecRequestBodySelection.defaultJSONBodyText(for: endpoint) == #"{"name":""}"#)
}
