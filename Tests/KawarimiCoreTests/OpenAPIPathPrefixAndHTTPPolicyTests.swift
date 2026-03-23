import Foundation
import KawarimiCore
import Testing

@Test func openAPIPathPrefixTrimsAndNormalizes() {
    #expect(OpenAPIPathPrefix.normalizedPrefix("api") == "/api")
    #expect(OpenAPIPathPrefix.normalizedPrefix("/api/") == "/api")
    #expect(OpenAPIPathPrefix.normalizedPrefix("  /v1/  ") == "/v1")
}

@Test func openAPIPathPrefixEmptyUsesDefault() {
    #expect(OpenAPIPathPrefix.normalizedPrefix("", defaultIfEmpty: "/api") == "/api")
    #expect(OpenAPIPathPrefix.normalizedPrefix("   ", defaultIfEmpty: "/api") == "/api")
}

@Test func openAPIPathPrefixServerURLForMount() throws {
    let url = try #require(OpenAPIPathPrefix.serverURLForOpenAPIPathOnlyMount(pathPrefix: "/api"))
    #expect(url.scheme == "https")
    #expect(url.host == "kawarimi.openapi.invalid")
    #expect(url.path == "/api")
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
        #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, bodyUTF8: nil))
        #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, bodyUTF8: empty))
        #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, bodyUTF8: nonEmpty))
        #expect(!HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: m))
    }
}

@Test func httpRequestBodyPolicyPostPutPatchAlwaysAttach() {
    let empty = Data()
    for m in ["POST", "PUT", "PATCH"] {
        #expect(HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, bodyUTF8: nil))
        #expect(HTTPRequestBodyPolicy.shouldAttachRequestBody(method: m, bodyUTF8: empty))
        #expect(HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: m))
    }
}

@Test func httpRequestBodyPolicyDeleteOptionalBody() {
    #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: "DELETE", bodyUTF8: nil))
    #expect(!HTTPRequestBodyPolicy.shouldAttachRequestBody(method: "DELETE", bodyUTF8: Data()))
    let data = Data([0x22])
    #expect(HTTPRequestBodyPolicy.shouldAttachRequestBody(method: "DELETE", bodyUTF8: data))
    #expect(HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: "DELETE"))
}
