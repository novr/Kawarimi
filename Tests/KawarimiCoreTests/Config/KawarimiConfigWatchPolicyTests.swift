import KawarimiCore
import Testing

@Suite("KawarimiConfigWatchPolicy")
struct KawarimiConfigWatchPolicyTests {
    @Test func fromEnvironment_unset_isEnabled() {
        #expect(KawarimiConfigWatchPolicy.fromEnvironment([:]) == .enabled)
    }

    @Test func fromEnvironment_one_isEnabled() {
        #expect(
            KawarimiConfigWatchPolicy.fromEnvironment([KawarimiConfigWatchPolicy.environmentKey: "1"])
                == .enabled
        )
    }

    @Test func fromEnvironment_zero_isDisabled() {
        #expect(
            KawarimiConfigWatchPolicy.fromEnvironment([KawarimiConfigWatchPolicy.environmentKey: "0"])
                == .disabled
        )
    }

    @Test func fromEnvironment_typo_staysEnabled() {
        #expect(
            KawarimiConfigWatchPolicy.fromEnvironment([KawarimiConfigWatchPolicy.environmentKey: "false"])
                == .enabled
        )
    }
}
