import Foundation

/// Whether ``KawarimiConfigStore`` watches `kawarimi.json` on disk and calls ``KawarimiConfigStore/reloadFromDisk()``.
public enum KawarimiConfigWatchPolicy: Sendable, Equatable {
    case enabled
    case disabled

    /// Environment variable: unset or `1` → enabled; `0` → disabled. Other values stay enabled.
    public static let environmentKey = "KAWARIMI_CONFIG_WATCH"

    public var isEnabled: Bool {
        switch self {
        case .enabled: true
        case .disabled: false
        }
    }

    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self {
        guard let raw = environment[environmentKey] else { return .enabled }
        if raw == "0" { return .disabled }
        return .enabled
    }
}
