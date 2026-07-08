import Foundation
import HTTPTypes
import KawarimiCore

/// Admin `__kawarimi/*` HTTP. Returns `nil` for non-admin requests because those paths are not OpenAPI operations.
public struct KawarimiAdminHTTPHandler: Sendable {
    public let store: KawarimiConfigStore
    public let specWireData: @Sendable () async throws -> Data

    public init(
        store: KawarimiConfigStore,
        specWireData: @escaping @Sendable () async throws -> Data
    ) {
        self.store = store
        self.specWireData = specWireData
    }

    public func handle(
        request: HTTPRequest,
        body: Data?
    ) async throws -> (HTTPResponse, Data?)? {
        let pathOnly = KawarimiRequestPath.pathOnly(request.path)
        guard KawarimiAdminPath.isManagementRequestPath(pathOnly) else {
            return nil
        }
        let pathPrefix = await store.pathPrefix
        guard let route = KawarimiAdminRoute.matching(
            requestPath: pathOnly,
            method: request.method,
            pathPrefix: pathPrefix
        ) else {
            return nil
        }

        switch route {
        case .configure:
            return try await handleConfigure(body: body)
        case .remove:
            return try await handleRemove(body: body)
        case .status:
            return try await overridesJSONResponse(route: .status)
        case .reset:
            try await store.reset()
            return try await overridesJSONResponse(route: .reset)
        case .reload:
            let result = await store.reloadFromDisk()
            return try await overridesJSONResponse(
                route: .reload,
                extraHeaderFields: [
                    KawarimiAdminHeaders.reloadOutcomeField: result.httpHeaderValue,
                ]
            )
        case .spec:
            let data = try await specWireData()
            return jsonResponse(statusCode: route.successStatusCode, body: data)
        }
    }

    private enum MockOverrideBodyDecodeResult {
        case success(MockOverride)
        case failure((HTTPResponse, Data?))
    }

    private func handleConfigure(body: Data?) async throws -> (HTTPResponse, Data?) {
        switch decodeMockOverrideBody(body) {
        case .failure(let response):
            return response
        case .success(let override):
            if let overrideBody = override.body, overrideBody.utf8.count > MockOverride.maxBodyLength {
                return plainTextResponse(
                    statusCode: 413,
                    message: "Override body exceeds \(MockOverride.maxBodyLength) bytes"
                )
            }
            do {
                try await store.configure(override)
                return try await overridesJSONResponse(route: .configure)
            } catch let error as KawarimiConfigStoreError {
                if case .bodyTooLong = error {
                    return plainTextResponse(statusCode: 413, message: "\(error)")
                }
                return plainTextResponse(statusCode: 500, message: "\(error)")
            } catch {
                return plainTextResponse(statusCode: 500, message: "\(error)")
            }
        }
    }

    private func handleRemove(body: Data?) async throws -> (HTTPResponse, Data?) {
        switch decodeMockOverrideBody(body) {
        case .failure(let response):
            return response
        case .success(let override):
            do {
                try await store.removeOverride(override)
                return try await overridesJSONResponse(route: .remove)
            } catch {
                return plainTextResponse(statusCode: 500, message: "\(error)")
            }
        }
    }

    private func decodeMockOverrideBody(_ body: Data?) -> MockOverrideBodyDecodeResult {
        do {
            let data = body ?? Data()
            let override = try JSONDecoder().decode(MockOverride.self, from: data)
            return .success(override)
        } catch {
            return .failure(plainTextResponse(statusCode: 400, message: "Invalid JSON body: \(error)"))
        }
    }

    private func overridesJSONResponse(
        route: KawarimiAdminRoute,
        extraHeaderFields: [HTTPField.Name: String] = [:]
    ) async throws -> (HTTPResponse, Data?) {
        let overrides = await store.overrides()
        let data = try JSONEncoder().encode(overrides)
        var headerFields = extraHeaderFields
        headerFields[.contentType] = KawarimiAdminHeaders.jsonContentType
        return jsonResponse(statusCode: route.successStatusCode, body: data, headerFields: headerFields)
    }

    private func jsonResponse(
        statusCode: Int,
        body: Data,
        headerFields: [HTTPField.Name: String] = [:]
    ) -> (HTTPResponse, Data?) {
        var response = HTTPResponse(status: .init(code: statusCode))
        for (name, value) in headerFields {
            response.headerFields[name] = value
        }
        if response.headerFields[.contentType] == nil {
            response.headerFields[.contentType] = KawarimiAdminHeaders.jsonContentType
        }
        return (response, body)
    }

    private func plainTextResponse(statusCode: Int, message: String) -> (HTTPResponse, Data?) {
        var response = HTTPResponse(status: .init(code: statusCode))
        response.headerFields[.contentType] = "text/plain"
        return (response, Data(message.utf8))
    }
}
