import Foundation
import HTTPTypes

public enum KawarimiSpecCrossCheck {
    public struct Result: Sendable, Equatable {
        public var errors: [String]
        public var warnings: [String]

        public init(errors: [String] = [], warnings: [String] = []) {
            self.errors = errors
            self.warnings = warnings
        }
    }

    public static func validate(
        overrides: [MockOverride],
        scenarios: [KawarimiScenario],
        spec: HengeSpecSnapshot
    ) -> Result {
        let index = SpecEndpointIndex(endpoints: spec.endpoints)
        var errors: [String] = []
        var warnings: [String] = []

        for override in overrides {
            let path = KawarimiRequestPath.pathOnly(override.path)
            let method = override.method
            guard let endpoint = index.endpoint(method: method, path: path) else {
                errors.append(overrideLabel(override) + " endpoint \(method.rawValue) \(path) not found in spec")
                continue
            }
            // Custom body skips responseMap at runtime — do not require status/example keys.
            if override.hasEffectiveCustomBody { continue }
            let exampleKeys = index.exampleKeys(for: endpoint, statusCode: override.statusCode)
            if exampleKeys.isEmpty {
                errors.append(
                    overrideLabel(override)
                        + " statusCode \(override.statusCode) not found on \(method.rawValue) \(path) in spec"
                )
                continue
            }
            let want = KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: override.exampleId)
            if !exampleKeys.contains(want) {
                let exampleLabel = override.exampleId ?? "(default)"
                errors.append(
                    overrideLabel(override)
                        + " exampleId \(exampleLabel) not found for status \(override.statusCode) on \(method.rawValue) \(path) in spec"
                )
            }
        }

        for scenario in scenarios {
            guard let scenarioId = KawarimiScenarioTokens.normalize(scenario.scenarioId) else { continue }
            for scase in scenario.cases {
                guard let kawarimiId = KawarimiScenarioTokens.normalize(scase.kawarimiId) else { continue }
                if !overrides.contains(where: { $0.rowId == scase.rowId }) {
                    errors.append(
                        "Scenario '\(scenarioId)' case '\(kawarimiId)': rowId \(scase.rowId.rawValue) not found in overrides"
                    )
                }
                guard let method = scase.endpoint.normalizedMethod() else { continue }
                let path = scase.endpoint.normalizedPath()
                if index.endpoint(method: method, path: path) == nil {
                    warnings.append(
                        "Scenario '\(scenarioId)' case '\(kawarimiId)': endpoint \(method.rawValue) \(path) not found in spec"
                    )
                }
            }
        }

        return Result(errors: errors, warnings: warnings)
    }

    private static func overrideLabel(_ override: MockOverride) -> String {
        if let rowId = override.rowId {
            return "Override rowId \(rowId.rawValue)"
        }
        let path = KawarimiRequestPath.pathOnly(override.path)
        return "Override \(override.method.rawValue) \(path) status \(override.statusCode)"
    }

    private struct SpecEndpointIndex {
        private let byRoute: [String: HengeSpecSnapshot.Endpoint]

        init(endpoints: [HengeSpecSnapshot.Endpoint]) {
            var map: [String: HengeSpecSnapshot.Endpoint] = [:]
            for endpoint in endpoints {
                map[Self.routeKey(method: endpoint.method, path: endpoint.path)] = endpoint
            }
            self.byRoute = map
        }

        func endpoint(method: HTTPRequest.Method, path: String) -> HengeSpecSnapshot.Endpoint? {
            byRoute[Self.routeKey(method: method, path: path)]
        }

        func exampleKeys(for endpoint: HengeSpecSnapshot.Endpoint, statusCode: Int) -> Set<String> {
            Set(
                endpoint.responses
                    .filter { $0.statusCode == statusCode }
                    .map { KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: $0.exampleId) }
            )
        }

        private static func routeKey(method: HTTPRequest.Method, path: String) -> String {
            "\(method.rawValue):\(KawarimiRequestPath.pathOnly(path))"
        }
    }
}
