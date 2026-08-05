import HTTPTypes
import KawarimiCore

package struct ScenarioBrowserItem: Identifiable, Sendable {
    package let id: String
    package let scenario: KawarimiScenario
    package var caseItems: [ScenarioCaseItem]

    package init(_ scenario: KawarimiScenario) {
        id = scenario.scenarioId
        self.scenario = scenario
        caseItems = scenario.cases.map { ScenarioCaseItem($0) }
    }
}

package struct ScenarioCaseItem: Identifiable, Sendable {
    package let id: String
    package let scenarioCase: KawarimiScenarioCase

    package init(_ scenarioCase: KawarimiScenarioCase) {
        id = scenarioCase.rowId.rawValue
        self.scenarioCase = scenarioCase
    }

    package var endpointRowKey: EndpointRowKey? {
        guard let method = scenarioCase.endpoint.normalizedMethod() else { return nil }
        return EndpointRowKey(method: method, path: scenarioCase.endpoint.normalizedPath())
    }
}

package enum ScenarioBrowserPresentation {
    package static func items(from scenarios: [KawarimiScenario]) -> [ScenarioBrowserItem] {
        scenarios.map { ScenarioBrowserItem($0) }
    }

    /// `true` when tapping the case can open a matching override row in the Endpoints tab.
    package static func canNavigate(
        rowId: MockOverrideRowID,
        pathPrefix: String,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride]
    ) -> Bool {
        OverrideExplorerDraftBootstrap.makeFreshDetail(
            rowId: rowId,
            pathPrefix: pathPrefix,
            endpoints: endpoints,
            overrides: overrides
        ) != nil
    }
}
