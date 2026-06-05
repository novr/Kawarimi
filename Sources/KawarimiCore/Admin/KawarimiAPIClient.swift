import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Includes a short body prefix in `localizedDescription` when present so failures are easier to diagnose.
public struct KawarimiAPIError: Error, LocalizedError, Sendable {
    public var statusCode: Int
    public var data: Data?

    public init(statusCode: Int, data: Data? = nil) {
        self.statusCode = statusCode
        self.data = data
    }

    public var errorDescription: String? {
        var msg = "HTTP \(statusCode)"
        if let data = data, let body = String(data: data, encoding: .utf8), !body.isEmpty {
            let snippet = body.prefix(200)
            msg += " — \(snippet)"
        }
        return msg
    }
}

/// Appends `__kawarimi/...` under `baseURL` (include the API mount point in the base URL).
public struct KawarimiAPIClient: Sendable {
    public var baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private func validateHTTPStatus(_ response: URLResponse?, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw KawarimiAPIError(statusCode: http.statusCode, data: data)
        }
    }

    private func specWireData() async throws -> Data {
        let url = KawarimiAdminRoute.adminURL(baseURL: baseURL, route: .spec)
        let (data, response) = try await session.data(from: url)
        try validateHTTPStatus(response, data: data)
        return data
    }

    /// Fetches and decodes `GET …/__kawarimi/spec` for any custom ``Decodable`` wire shape.
    /// For the standard Henge document, prefer ``fetchHengeSpec()`` or ``fetchSpec(as:)`` with a ``KawarimiFetchedSpec`` type.
    public func fetchSpec<T: Decodable & Sendable>(as type: T.Type) async throws -> T {
        let data = try await specWireData()
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Fetches the Henge wire document when your app links a host-generated ``KawarimiFetchedSpec`` (e.g. ``SpecResponse``).
    /// Henge-only app targets that do not link a generated API module should use ``fetchHengeSpec()`` instead.
    public func fetchSpec<Spec: KawarimiFetchedSpec>(as specType: Spec.Type) async throws -> Spec {
        let data = try await specWireData()
        return try JSONDecoder().decode(Spec.self, from: data)
    }

    /// Preferred way to load Henge spec for **`KawarimiConfigView(client:)`** and other clients that should not link a host-generated ``SpecResponse``.
    /// Decodes ``HengeSpecSnapshot`` from `GET …/__kawarimi/spec`.
    public func fetchHengeSpec() async throws -> HengeSpecSnapshot {
        try await fetchSpec(as: HengeSpecSnapshot.self)
    }

    public func fetchOverrides() async throws -> [MockOverride] {
        let url = KawarimiAdminRoute.adminURL(baseURL: baseURL, route: .status)
        let (data, response) = try await session.data(from: url)
        try validateHTTPStatus(response, data: data)
        return try JSONDecoder().decode([MockOverride].self, from: data)
    }

    /// Upserts one override and returns the current override list (`POST …/configure`).
    public func configure(override: MockOverride) async throws -> [MockOverride] {
        let url = KawarimiAdminRoute.adminURL(baseURL: baseURL, route: .configure)
        var request = URLRequest(url: url)
        request.httpMethod = KawarimiAdminRoute.configure.httpMethod.rawValue
        request.setValue(KawarimiAdminHeaders.jsonContentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(override)
        return try await performMutation(route: .configure, request: request)
    }

    /// Removes one override row and returns the current override list (`POST …/remove`).
    public func removeOverride(override: MockOverride) async throws -> [MockOverride] {
        let url = KawarimiAdminRoute.adminURL(baseURL: baseURL, route: .remove)
        var request = URLRequest(url: url)
        request.httpMethod = KawarimiAdminRoute.remove.httpMethod.rawValue
        request.setValue(KawarimiAdminHeaders.jsonContentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(override)
        return try await performMutation(route: .remove, request: request)
    }

    /// Clears all overrides and returns the current override list (`POST …/reset`).
    public func reset() async throws -> [MockOverride] {
        let url = KawarimiAdminRoute.adminURL(baseURL: baseURL, route: .reset)
        var request = URLRequest(url: url)
        request.httpMethod = KawarimiAdminRoute.reset.httpMethod.rawValue
        return try await performMutation(route: .reset, request: request)
    }

    /// Alias for ``configure(override:)`` — admin mutations return overrides in the response body ([#147](https://github.com/novr/Kawarimi/issues/147)); no separate ``GET …/status``.
    public func configureAndFetchOverrides(override: MockOverride) async throws -> [MockOverride] {
        try await configure(override: override)
    }

    /// Alias for ``removeOverride(override:)`` — see ``configureAndFetchOverrides(override:)``.
    public func removeAndFetchOverrides(override: MockOverride) async throws -> [MockOverride] {
        try await removeOverride(override: override)
    }

    /// Alias for ``reset()`` — see ``configureAndFetchOverrides(override:)``.
    public func resetAndFetchOverrides() async throws -> [MockOverride] {
        try await reset()
    }

    /// Convenience wrapper for `configure(override:)` with an explicit `exampleId` (`nil` = default example row).
    public func configure(
        path: String,
        method: String,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil,
        delayMs: Int? = nil
    ) async throws -> [MockOverride] {
        guard let override = MockOverride(
            path: path,
            method: method,
            statusCode: statusCode,
            exampleId: exampleId,
            isEnabled: isEnabled,
            body: body,
            contentType: contentType,
            delayMs: delayMs
        ) else {
            throw MockOverride.InvalidMethodStringError(rawMethod: method)
        }
        return try await configure(override: override)
    }

    /// Re-reads overrides from disk (`POST …/__kawarimi/reload`). Expects ``KawarimiAdminRoute/reload`` `successStatusCode`, `X-Kawarimi-Reload`, and a JSON override array (same as ``fetchOverrides()``).
    public func reload() async throws -> KawarimiConfigReloadResponse {
        let url = KawarimiAdminRoute.adminURL(baseURL: baseURL, route: .reload)
        var request = URLRequest(url: url)
        request.httpMethod = KawarimiAdminRoute.reload.httpMethod.rawValue
        let (data, response) = try await session.data(for: request)
        let http = try validateMutationHTTP(response, data: data, route: .reload)
        let raw = http.value(forHTTPHeaderField: KawarimiAdminHeaders.reloadOutcome) ?? ""
        guard let result = KawarimiConfigReloadResult(httpHeaderValue: raw) else {
            throw KawarimiAPIError(statusCode: http.statusCode, data: data)
        }
        let overrides = try decodeOverrides(from: data)
        return KawarimiConfigReloadResponse(result: result, overrides: overrides)
    }

    private func performMutation(route: KawarimiAdminRoute, request: URLRequest) async throws -> [MockOverride] {
        let (data, response) = try await session.data(for: request)
        _ = try validateMutationHTTP(response, data: data, route: route)
        return try decodeOverrides(from: data)
    }

    @discardableResult
    private func validateMutationHTTP(_ response: URLResponse?, data: Data?, route: KawarimiAdminRoute) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw KawarimiAPIError(statusCode: 0, data: data)
        }
        guard http.statusCode == route.successStatusCode else {
            throw KawarimiAPIError(statusCode: http.statusCode, data: data)
        }
        return http
    }

    private func decodeOverrides(from data: Data) throws -> [MockOverride] {
        try JSONDecoder().decode([MockOverride].self, from: data)
    }
}
