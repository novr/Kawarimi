import Foundation
import KawarimiCore
import Testing

@Suite("KawarimiUpstreamSettings")
struct KawarimiUpstreamSettingsTests {
    @Test func emptyEnvironmentDisablesForwarding() {
        let settings = KawarimiUpstreamSettings.fromEnvironment([:])
        #expect(!settings.isForwardingEnabled)
        #expect(settings.forwarding == nil)
        #expect(settings.invalidURLWarning == nil)
    }

    @Test func parsesOriginOnlyURL() throws {
        let settings = KawarimiUpstreamSettings.fromEnvironment([
            "KAWARIMI_UPSTREAM_URL": "https://staging.example.com:8443",
        ])
        let forwarding = try #require(settings.forwarding)
        #expect(settings.isForwardingEnabled)
        #expect(forwarding.origin.scheme == "https")
        #expect(forwarding.origin.host == "staging.example.com")
        #expect(forwarding.origin.port == 8443)
        #expect(forwarding.nonOriginPathWarning == nil)
    }

    @Test func warnsWhenURLIncludesPath() {
        let settings = KawarimiUpstreamSettings.fromEnvironment([
            "KAWARIMI_UPSTREAM_URL": "https://staging.example.com/api",
        ])
        #expect(settings.isForwardingEnabled)
        #expect(settings.forwarding?.nonOriginPathWarning != nil)
        #expect(settings.strictOriginViolation == false)
    }

    @Test func strictFailsWhenURLIncludesPath() {
        let settings = KawarimiUpstreamSettings.fromEnvironment([
            "KAWARIMI_UPSTREAM_URL": "https://staging.example.com/api",
            "KAWARIMI_UPSTREAM_STRICT": "1",
        ])
        #expect(settings.strictOriginViolation)
    }

    @Test func warnsWhenURLCannotBeParsed() {
        let settings = KawarimiUpstreamSettings.fromEnvironment([
            "KAWARIMI_UPSTREAM_URL": "not-a-valid-url",
        ])
        #expect(!settings.isForwardingEnabled)
        #expect(settings.invalidURLWarning != nil)
    }
}
