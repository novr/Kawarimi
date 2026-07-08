import KawarimiCore
import Testing
@testable import KawarimiHengeCore

private struct FakeMeta: SpecMetaProviding {
    var title: String
    var version: String
    var description: String?
    var serverURL: String
    var apiPathPrefix: String
}

@Test(.timeLimit(.minutes(1))) func metaPresentationTrimsApiDescription() {
    let withText = FakeMeta(title: "T", version: "1", description: "  Demo API  ", serverURL: "http://x", apiPathPrefix: "")
    #expect(MetaPresentation.apiDescription(for: withText) == "Demo API")

    let empty = FakeMeta(title: "T", version: "1", description: "   ", serverURL: "http://x", apiPathPrefix: "")
    #expect(MetaPresentation.apiDescription(for: empty) == nil)
}
