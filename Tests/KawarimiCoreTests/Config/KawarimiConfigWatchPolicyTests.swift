import KawarimiCore
import Testing

@Suite("KawarimiConfigWatchPolicy", .timeLimit(.minutes(1)))
struct KawarimiConfigWatchPolicyTests {
    @Test(.timeLimit(.minutes(1))) func fromEnvironment_unset_isEnabled() {
        #expect(KawarimiConfigWatchPolicy.fromEnvironment([:]) == .enabled)
    }

    @Test(.timeLimit(.minutes(1))) func fromEnvironment_one_isEnabled() {
        #expect(
            KawarimiConfigWatchPolicy.fromEnvironment([KawarimiConfigWatchPolicy.environmentKey: "1"])
                == .enabled
        )
    }

    @Test(.timeLimit(.minutes(1))) func fromEnvironment_zero_isDisabled() {
        #expect(
            KawarimiConfigWatchPolicy.fromEnvironment([KawarimiConfigWatchPolicy.environmentKey: "0"])
                == .disabled
        )
    }

    @Test(.timeLimit(.minutes(1))) func fromEnvironment_typo_staysEnabled() {
        #expect(
            KawarimiConfigWatchPolicy.fromEnvironment([KawarimiConfigWatchPolicy.environmentKey: "false"])
                == .enabled
        )
    }
}
