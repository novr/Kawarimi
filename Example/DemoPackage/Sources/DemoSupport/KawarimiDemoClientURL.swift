import Foundation

public enum KawarimiDemoClientURL {
    /// Matches `servers` in the bundled Demo `openapi.yaml`.
    public static let defaultBaseURL = "http://127.0.0.1:8080/api"

    /// Kawarimi admin client base URL (override with `KAWARIMI_BASE_URL`).
    public static var clientBaseURL: URL? {
        let raw = ProcessInfo.processInfo.environment["KAWARIMI_BASE_URL"] ?? defaultBaseURL
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
