import Foundation
import HTTPTypes

public enum KawarimiScenarioResolutionReason: String, Sendable {
    case scenarioHeaderMissing
    case invalidHeader
    case scenarioNotFound
    case duplicateCases
    case caseNotFound
    case overrideNotFound
    case endpointMismatch
}

public enum KawarimiScenarioResolution: Sendable, Equatable {
    case matched(response: KawarimiDynamicMockResponse, nextKawarimiId: String?, delayMs: Int?)
    case fallback(reason: KawarimiScenarioResolutionReason)
}

public enum KawarimiScenarioResolver {
    public static func resolve(
        scenarios: [KawarimiScenario],
        overrides: [MockOverride],
        responseMap: KawarimiMockResponseResolver.NestedResponseMap,
        requestPath: String,
        method: HTTPRequest.Method,
        scenarioIdHeaderRaw: String?,
        kawarimiIdHeaderRaw: String?
    ) -> KawarimiScenarioResolution {
        guard let scenarioId = KawarimiScenarioTokens.normalize(scenarioIdHeaderRaw) else {
            return .fallback(reason: scenarioIdHeaderRaw == nil ? .scenarioHeaderMissing : .invalidHeader)
        }
        guard let scenario = scenarios.first(where: { KawarimiScenarioTokens.normalize($0.scenarioId) == scenarioId }) else {
            return .fallback(reason: .scenarioNotFound)
        }

        guard let kawarimiId = KawarimiScenarioTokens.normalize(kawarimiIdHeaderRaw) ?? KawarimiScenarioTokens.normalize(scenario.initial) else {
            return .fallback(reason: .invalidHeader)
        }
        let pathOnly = KawarimiRequestPath.pathOnly(requestPath)

        let matches = scenario.cases.filter { scase in
            guard KawarimiScenarioTokens.normalize(scase.kawarimiId) == kawarimiId else { return false }
            guard scase.endpoint.normalizedMethod() == method else { return false }
            return scase.endpoint.normalizedPath() == pathOnly
        }

        if matches.count > 1 {
            return .fallback(reason: .duplicateCases)
        }
        guard let matchedCase = matches.first else {
            return .fallback(reason: .caseNotFound)
        }
        guard let override = overrides.first(where: { $0.rowId == matchedCase.rowId }) else {
            return .fallback(reason: .overrideNotFound)
        }

        let overridePath = KawarimiRequestPath.pathOnly(override.path)
        if override.method != method || overridePath != pathOnly {
            return .fallback(reason: .endpointMismatch)
        }

        let resolved = KawarimiDynamicMockResponseResolver.resolve(
            override: override,
            responseMap: responseMap,
            methodUppercased: method.rawValue.uppercased()
        )

        return .matched(
            response: resolved,
            nextKawarimiId: KawarimiScenarioTokens.normalize(matchedCase.next),
            delayMs: override.delayMs
        )
    }
}
