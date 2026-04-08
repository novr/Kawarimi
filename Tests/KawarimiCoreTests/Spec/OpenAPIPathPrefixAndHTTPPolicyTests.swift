import Foundation
import KawarimiCore
import Testing

@Test func kawarimiPathSplitJoinMatchesFormerSpecPrefix() {
    func j(_ s: String) -> String {
        KawarimiPath.joinPathPrefix(KawarimiPath.splitPathSegments(s))
    }
    #expect(j("") == "")
    #expect(j("   ") == "")
    #expect(j("/") == "")
    #expect(j("api") == "/api")
    #expect(j("/v1/") == "/v1")
    #expect(KawarimiPath.splitPathSegments("/a/b") == ["a", "b"])
}

@Test func kawarimiPathAlignedWithPrefix() {
    #expect(KawarimiPath.aligned(path: "/greet", pathPrefix: "/api") == "/api/greet")
    #expect(KawarimiPath.aligned(path: "/api/greet", pathPrefix: "/api") == "/api/greet")
    #expect(KawarimiPath.aligned(path: "greet", pathPrefix: "/api") == "/api/greet")
}

@Test func kawarimiPathAlignedRootPrefix() {
    #expect(KawarimiPath.aligned(path: "/app/setting", pathPrefix: "") == "/app/setting")
    #expect(KawarimiPath.aligned(path: "greet", pathPrefix: "") == "/greet")
}

@Test func kawarimiAdminPathDetectsManagementSegment() {
    #expect(KawarimiAdminPath.isManagementRequestPath("/api/__kawarimi/spec"))
    #expect(KawarimiAdminPath.isManagementRequestPath("/__kawarimi/configure"))
    #expect(KawarimiAdminPath.isManagementRequestPath("/v1/__kawarimi/status"))
}

@Test func kawarimiAdminPathRejectsNonSegmentMatch() {
    #expect(!KawarimiAdminPath.isManagementRequestPath("/api/greet"))
    #expect(!KawarimiAdminPath.isManagementRequestPath("/v1/foo__kawarimi/x"))
    #expect(!KawarimiAdminPath.isManagementRequestPath("/api/__kawarimi_backup/x"))
}

@Test func httpRequestBodyPolicyNoBodyForGetHead() {
    let empty = Data()
    let nonEmpty = Data("{}".utf8)
    for m in ["GET", "HEAD", "OPTIONS", "TRACE"] {
        #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, body: nil))
        #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, body: empty))
        #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, body: nonEmpty))
        #expect(!HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: m))
    }
}

@Test func httpRequestBodyPolicyPostPutPatchAlwaysAttach() {
    let empty = Data()
    for m in ["POST", "PUT", "PATCH"] {
        #expect(HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, body: nil))
        #expect(HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, body: empty))
        #expect(HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: m))
    }
}

@Test func httpRequestBodyPolicyDeleteOptionalBody() {
    #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: "DELETE", body: nil))
    #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: "DELETE", body: Data()))
    let data = Data([0x22])
    #expect(HTTPRequestBodyPolicy.shouldAttachRequestBody(method: "DELETE", body: data))
    #expect(HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: "DELETE"))
}
