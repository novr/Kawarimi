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
        guard let scenarioId = normalizeToken(scenarioIdHeaderRaw) else {
            return .fallback(reason: scenarioIdHeaderRaw == nil ? .scenarioHeaderMissing : .invalidHeader)
        }
        guard let scenario = scenarios.first(where: { normalizeToken($0.scenarioId) == scenarioId }) else {
            return .fallback(reason: .scenarioNotFound)
        }

        guard let kawarimiId = normalizeToken(kawarimiIdHeaderRaw) ?? normalizeToken(scenario.initial) else {
            return .fallback(reason: .invalidHeader)
        }
        let pathOnly = KawarimiRequestPath.pathOnly(requestPath)

        let matches = scenario.cases.filter { scase in
            guard normalizeToken(scase.kawarimiId) == kawarimiId else { return false }
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
            nextKawarimiId: normalizeToken(matchedCase.next),
            delayMs: override.delayMs
        )
    }

    private static func normalizeToken(_ raw: String?) -> String? {
        guard let token = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard token.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return token
    }
}
