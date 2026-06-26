import Foundation
import HTTPTypes

public enum KawarimiScenarioDefaults {
    public static let fileName = "kawarimi-scenarios.json"
    public static let environmentKey = "KAWARIMI_SCENARIOS_CONFIG"

    /// Resolution order: `explicit` → ``environmentKey`` → `{config directory}/``fileName````.
    public static func resolvedPath(
        explicit: String? = nil,
        configAbsolutePath: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        if let env = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            return env
        }
        let baseDir = (configAbsolutePath as NSString).deletingLastPathComponent
        return (baseDir as NSString).appendingPathComponent(fileName)
    }
}

public struct KawarimiScenariosFile: Codable, Sendable, Equatable {
    public var scenarios: [KawarimiScenario]

    public init(scenarios: [KawarimiScenario] = []) {
        self.scenarios = scenarios
    }
}

public struct KawarimiScenario: Codable, Sendable, Equatable {
    public var scenarioId: String
    public var initial: String
    public var cases: [KawarimiScenarioCase]

    public init(scenarioId: String, initial: String, cases: [KawarimiScenarioCase] = []) {
        self.scenarioId = scenarioId
        self.initial = initial
        self.cases = cases
    }
}

public struct KawarimiScenarioCase: Codable, Sendable, Equatable {
    public var kawarimiId: String
    public var next: String?
    public var rowId: MockOverrideRowID
    public var endpoint: KawarimiScenarioEndpoint

    public init(
        kawarimiId: String,
        next: String? = nil,
        rowId: MockOverrideRowID,
        endpoint: KawarimiScenarioEndpoint
    ) {
        self.kawarimiId = kawarimiId
        self.next = next
        self.rowId = rowId
        self.endpoint = endpoint
    }
}

public struct KawarimiScenarioEndpoint: Codable, Sendable, Equatable {
    public var method: String
    public var path: String

    public init(method: String, path: String) {
        self.method = method
        self.path = path
    }

    public func normalizedMethod() -> HTTPRequest.Method? {
        HTTPRequest.Method(method.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    public func normalizedPath() -> String {
        KawarimiRequestPath.pathOnly(path)
    }
}
