import Foundation

/// HTTP headers for scenario orchestration (`ServerMiddleware` / client middleware).
public enum KawarimiScenarioHeaders {
    /// Selects which scenario definition to apply (`kawarimi-scenarios.json`).
    public static let scenarioId = "X-Kawarimi-Scenario-Id"

    /// Current step within the selected scenario; omitted on first request (server uses `scenario.initial`).
    public static let kawarimiId = "X-Kawarimi-Id"

    /// Next step for the client to send as ``kawarimiId`` on the following request; omitted at terminal cases.
    public static let nextKawarimiId = "X-Next-Kawarimi-Id"
}
