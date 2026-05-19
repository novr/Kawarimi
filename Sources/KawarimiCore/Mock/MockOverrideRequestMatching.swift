import Foundation
import HTTPTypes

/// Shared rules for matching persisted overrides to OpenAPI operations or incoming HTTP requests.
public enum MockOverrideRequestMatching {
    /// Matches an override to an OpenAPI operation row (explorer / configure identity).
    public static func overrideMatchesOperation(
        _ override: MockOverride,
        method: HTTPRequest.Method,
        operationPath: String,
        operationID: String?,
        pathPrefix: String
    ) -> Bool {
        guard override.method == method else { return false }
        if operationIDsMatch(override.name, operationID) { return true }
        let alignedOverride = KawarimiPath.aligned(path: override.path, pathPrefix: pathPrefix)
        let alignedOperation = KawarimiPath.aligned(path: operationPath, pathPrefix: pathPrefix)
        return alignedOverride == alignedOperation
    }

    /// Matches an override to an incoming HTTP request (path template or `operationId` via ``MockOverride/name``).
    public static func overrideMatchesIncomingRequest(
        _ override: MockOverride,
        requestPath: String,
        method: HTTPRequest.Method,
        operationID: String?,
        pathPrefix: String
    ) -> Bool {
        guard override.method == method else { return false }
        if operationIDsMatch(override.name, operationID) { return true }
        let actual = KawarimiPath.aligned(path: requestPath, pathPrefix: pathPrefix)
        let template = KawarimiPath.aligned(path: override.path, pathPrefix: pathPrefix)
        return PathTemplate.matches(actual: actual, template: template)
    }

    /// Enabled overrides for an incoming request, tie-break order (first wins).
    public static func matchingEnabledOverrides(
        in overrides: [MockOverride],
        requestPath: String,
        method: HTTPRequest.Method,
        operationID: String?,
        pathPrefix: String,
        exampleIdHeaderRaw: String?
    ) -> [MockOverride] {
        let path = KawarimiRequestPath.pathOnly(requestPath)
        let candidates = overrides.filter { ov in
            ov.isEnabled
                && overrideMatchesIncomingRequest(
                    ov,
                    requestPath: path,
                    method: method,
                    operationID: operationID,
                    pathPrefix: pathPrefix
                )
        }
        let narrowed = KawarimiMockRequestHeaders.filterOverrides(candidates, exampleIdHeaderRaw: exampleIdHeaderRaw)
        return MockOverride.sortedForOverrideTieBreak(narrowed)
    }

    /// Enabled overrides for an OpenAPI operation row (Henge explorer / configure identity), tie-break order (first wins).
    public static func matchingEnabledOverridesForOperation(
        in overrides: [MockOverride],
        method: HTTPRequest.Method,
        operationPath: String,
        operationID: String?,
        pathPrefix: String
    ) -> [MockOverride] {
        let candidates = overrides.filter { ov in
            ov.isEnabled
                && overrideMatchesOperation(
                    ov,
                    method: method,
                    operationPath: operationPath,
                    operationID: operationID,
                    pathPrefix: pathPrefix
                )
        }
        return MockOverride.sortedForOverrideTieBreak(candidates)
    }

    /// First enabled override for an OpenAPI operation row after tie-break.
    public static func primaryEnabledOverrideForOperation(
        in overrides: [MockOverride],
        method: HTTPRequest.Method,
        operationPath: String,
        operationID: String?,
        pathPrefix: String
    ) -> MockOverride? {
        matchingEnabledOverridesForOperation(
            in: overrides,
            method: method,
            operationPath: operationPath,
            operationID: operationID,
            pathPrefix: pathPrefix
        ).first
    }

    /// First enabled override for an incoming request after header narrowing and tie-break.
    public static func primaryEnabledOverride(
        in overrides: [MockOverride],
        requestPath: String,
        method: HTTPRequest.Method,
        operationID: String?,
        pathPrefix: String,
        exampleIdHeaderRaw: String?
    ) -> MockOverride? {
        matchingEnabledOverrides(
            in: overrides,
            requestPath: requestPath,
            method: method,
            operationID: operationID,
            pathPrefix: pathPrefix,
            exampleIdHeaderRaw: exampleIdHeaderRaw
        ).first
    }

    private static func operationIDsMatch(_ overrideName: String?, _ operationID: String?) -> Bool {
        let name = overrideName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let op = operationID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !name.isEmpty && !op.isEmpty && name == op
    }
}
