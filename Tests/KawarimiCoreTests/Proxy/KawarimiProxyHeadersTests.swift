import HTTPTypes
import KawarimiCore
import Testing

@Suite("KawarimiProxyHeaders")
struct KawarimiProxyHeadersTests {
    @Test func stripsHopByHopRequestHeaders() {
        var fields = HTTPFields()
        fields[HTTPField.Name("Connection")!] = "close"
        fields[HTTPField.Name("Host")!] = "localhost"
        fields[HTTPField.Name(KawarimiMockRequestHeaders.exampleId)!] = "success"
        fields[HTTPField.Name("Authorization")!] = "Bearer token"

        let forwarded = KawarimiProxyHeaders.forwardingRequestHeaders(from: fields)
        #expect(forwarded[HTTPField.Name("Connection")!] == nil)
        #expect(forwarded[HTTPField.Name("Host")!] == nil)
        #expect(forwarded[HTTPField.Name(KawarimiMockRequestHeaders.exampleId)!] == nil)
        #expect(forwarded[HTTPField.Name("Authorization")!] == "Bearer token")
    }

    @Test func stripsKawarimiControlResponseHeaders() {
        var fields = HTTPFields()
        fields[HTTPField.Name("Connection")!] = "close"
        fields[HTTPField.Name("Content-Type")!] = "application/json"
        fields[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] = "step-2"
        fields[HTTPField.Name(KawarimiProxyHeaders.proxyAction)!] = KawarimiProxyHeaders.actionForward

        let forwarded = KawarimiProxyHeaders.forwardingResponseHeaders(from: fields)
        #expect(forwarded[HTTPField.Name("Connection")!] == nil)
        #expect(forwarded[HTTPField.Name("Content-Type")!] == "application/json")
        #expect(forwarded[HTTPField.Name(KawarimiScenarioHeaders.nextKawarimiId)!] == nil)
        #expect(forwarded[HTTPField.Name(KawarimiProxyHeaders.proxyAction)!] == nil)
    }
}
