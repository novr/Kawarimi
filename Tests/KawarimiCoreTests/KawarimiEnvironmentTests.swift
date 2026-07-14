import KawarimiCore
import Testing

@Suite("KawarimiEnvironment")
struct KawarimiEnvironmentTests {
    @Test func isTruthy_nil_isFalse() {
        #expect(!KawarimiEnvironment.isTruthy(nil))
    }

    @Test func isTruthy_truthyValues() {
        for value in ["1", "true", "TRUE", " yes ", "On"] {
            #expect(KawarimiEnvironment.isTruthy(value))
        }
    }

    @Test func isTruthy_otherValues_areFalse() {
        for value in ["", "0", "false", "no", "off", "2", "maybe"] {
            #expect(!KawarimiEnvironment.isTruthy(value))
        }
    }
}
