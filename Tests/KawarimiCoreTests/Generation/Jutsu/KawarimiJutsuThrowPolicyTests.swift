import Foundation
import KawarimiJutsu
import Testing

@Test func kawarimiHandlerThrowsWhenPolicyIsThrowAndResponseIsNonJson() throws {
    guard let url = KawarimiJutsuTestSupport.fixtureURL(name: "openapi-xml-success-response", extension: "yaml") else {
        Issue.record("fixture not found")
        return
    }
    let document = try KawarimiJutsu.loadOpenAPISpec(path: url.path())
    do {
        _ = try KawarimiJutsu.generateKawarimiHandlerSource(
            document: document,
            namingStrategy: .defensive,
            handlerStubPolicy: .throw
        )
        Issue.record("expected handlerGenerationUnsupported")
    } catch let error as KawarimiJutsuError {
        if case .handlerGenerationUnsupported(let operationId, let detail) = error {
            #expect(operationId == "getReport")
            #expect(detail.contains("non-JSON"))
        } else {
            Issue.record("unexpected KawarimiJutsuError: \(error)")
        }
    }
}
