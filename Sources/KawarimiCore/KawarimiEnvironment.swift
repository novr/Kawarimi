import Foundation

public enum KawarimiEnvironment {
    /// `1`, `true`, `yes`, and `on` (case-insensitive, trimmed) are treated as enabled.
    public static func isTruthy(_ raw: String?) -> Bool {
        guard let raw else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
