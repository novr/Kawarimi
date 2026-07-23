import Foundation
import KawarimiCore
import Testing

@Test func mockFailureBehaviorConnectionCloseThrows() async throws {
    await #expect(throws: KawarimiMockFailureError.connectionClose) {
        try await MockFailureBehavior.applyIfNeeded(.connectionClose)
    }
}

@Test func mockFailureBehaviorHangRespectsCancellation() async throws {
    let task = Task {
        try await MockFailureBehavior.applyIfNeeded(.hang)
    }
    try await Task.sleep(for: .milliseconds(20))
    task.cancel()
    await #expect(throws: CancellationError.self) {
        _ = try await task.value
    }
}

@Test func mockOverrideEncodeDecodeFailureMode() throws {
    let override = MockOverride(
        path: "/api/greet",
        method: "GET",
        statusCode: 200,
        failureMode: .hang
    )!
    let decoded = try JSONDecoder().decode(MockOverride.self, from: try JSONEncoder().encode(override))
    #expect(decoded.failureMode == .hang)
}

@Test func mockOverrideRejectsUnknownFailureMode() throws {
    let json = """
    {
      "path": "/api/greet",
      "method": "GET",
      "statusCode": 200,
      "failureMode": "timeout"
    }
    """
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(MockOverride.self, from: Data(json.utf8))
    }
}
