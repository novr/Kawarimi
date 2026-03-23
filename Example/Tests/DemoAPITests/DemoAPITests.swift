import DemoAPI
import Foundation
import Testing

/// 実サーバなしで、生成モック Transport が契約どおり応答するかだけを見る。
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
