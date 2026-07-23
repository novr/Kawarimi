import Foundation

public enum MockFailureMode: String, Codable, Sendable {
    case hang
    case connectionClose
}

public enum KawarimiMockFailureError: Error, Sendable {
    case connectionClose
}

public enum MockFailureBehavior {
    public static func applyIfNeeded(_ mode: MockFailureMode?) async throws {
        guard let mode else { return }
        switch mode {
        case .hang:
            try await hangUntilCancelled()
        case .connectionClose:
            throw KawarimiMockFailureError.connectionClose
        }
    }

    private static func hangUntilCancelled() async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(3600))
        }
        throw CancellationError()
    }
}
