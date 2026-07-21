import Foundation
@testable import KawarimiJutsu
import Testing

// Compile-time smoke: escaped stub labels from `swiftMemberName` must be valid Swift argument labels (#209).
@Test(
    arguments: KawarimiNamingStrategy.swiftReservedKeywordsForTesting,
    [KawarimiNamingStrategy.defensive, .idiomatic]
)
func reservedHandlerStubLabelsTypecheck(reservedName: String, strategy: KawarimiNamingStrategy) throws {
    let label = try strategy.swiftMemberName(for: reservedName)
    let source = """
    struct StubBody {
        init(\(label): String) {}
    }
    let _ = StubBody(\(label): "example-value")
    """
    try KawarimiJutsuTestSupport.assertSwiftSnippetTypechecks(source)
}
