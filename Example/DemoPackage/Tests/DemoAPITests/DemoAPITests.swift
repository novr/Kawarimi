import DemoAPI
import Foundation
import Testing

@Test func kawarimiHandlerDefaultStubMatchesOpenAPIExample() async throws {
    let handler = KawarimiHandler()
    let response = try await handler.getGreeting(.init())
    switch response {
    case .ok(let ok):
        if case .json(let body) = ok.body {
            #expect(body.message == "Hello from API")
        } else {
            Issue.record("レスポンスボディが .json でない")
        }
    default:
        Issue.record("期待 .ok だが \(response) だった")
    }
}

@Test func kawarimiHandlerOnClosureOverridesResponse() async throws {
    var handler = KawarimiHandler()
    handler.onGetGreeting = { _ in
        .ok(.init(body: .json(.init(message: "Witness override"))))
    }
    let response = try await handler.getGreeting(.init())
    switch response {
    case .ok(let ok):
        if case .json(let body) = ok.body {
            #expect(body.message == "Witness override")
        } else {
            Issue.record("レスポンスボディが .json でない")
        }
    default:
        Issue.record("期待 .ok だが \(response) だった")
    }
}

@Test func clientWithKawarimiReturnsOk() async throws {
    let serverURL = URL(string: "http://localhost/api")!
    let client = Client(serverURL: serverURL, transport: Kawarimi())
    let response = try await client.getGreeting(.init())

    switch response {
    case .ok(let ok):
        if case .json(let body) = ok.body {
            #expect(body.message == "Hello from API", "Kawarimi モックは openapi の example を返す")
        } else {
            Issue.record("レスポンスボディが .json でない")
        }
    default:
        Issue.record("期待 .ok だが \(response) だった")
    }
}
