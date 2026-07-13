import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime

#if canImport(OSLog)
import OSLog
private let kawarimiProxyForwarderLog = Logger(subsystem: "Kawarimi", category: "KawarimiProxy")
#endif

public struct KawarimiUpstreamHTTPForwarder: Sendable {
    private let upstreamOrigin: URL
    private let transport: KawarimiProxyURLSessionTransport
    private let proxyDebug: Bool

    public init(upstreamOrigin: URL, proxyDebug: Bool = false) {
        self.upstreamOrigin = upstreamOrigin
        self.proxyDebug = proxyDebug
        self.transport = .live()
    }

    init(upstreamOrigin: URL, proxyDebug: Bool = false, transport: KawarimiProxyURLSessionTransport) {
        self.upstreamOrigin = upstreamOrigin
        self.proxyDebug = proxyDebug
        self.transport = transport
    }

    public func forward(
        request: HTTPRequest,
        body: HTTPBody?,
        pathPrefix: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let targetURL = Self.buildTargetURL(
            request: request,
            upstreamOrigin: upstreamOrigin,
            pathPrefix: pathPrefix
        ) else {
            return Self.badGatewayResponse(message: "Invalid upstream target URL")
        }

        var urlRequest = URLRequest(url: targetURL)
        urlRequest.httpMethod = request.method.rawValue

        let hasBody = body.map { !KawarimiProxyRequestBody.isEmpty($0) } ?? false
        let forwardedHeaders = KawarimiProxyHeaders.forwardingRequestHeaders(
            from: request.headerFields,
            omitContentLength: hasBody
        )
        Self.applyForwardedHeaders(forwardedHeaders, to: &urlRequest)

        do {
            let (http, responseBody) = try await transport.send(urlRequest, body: hasBody ? body : nil)
            var response = HTTPResponse(status: .init(code: http.statusCode))
            // Cookie-based session auth is out of scope for v1; Foundation collapses multi-value Set-Cookie.
            for (name, value) in http.allHeaderFields {
                guard let name = name as? String, let value = value as? String else { continue }
                guard let fieldName = HTTPField.Name(name) ?? HTTPField.Name(name.lowercased()) else { continue }
                response.headerFields.append(HTTPField(name: fieldName, value: value))
            }
            response.headerFields = KawarimiProxyHeaders.forwardingResponseHeaders(from: response.headerFields)
            return (response, responseBody)
        } catch let error as KawarimiProxyForwardError {
            switch error {
            case .bodyTooLarge(let limit):
                return Self.payloadTooLargeResponse(limit: limit)
            case .responseTooLarge(let limit):
                return Self.badGatewayResponse(message: "Upstream response exceeds \(limit) bytes")
            }
        } catch {
            logForwardFailure(error)
            return Self.badGatewayResponse(message: "Upstream unreachable")
        }
    }

    public static func buildTargetURL(
        request: HTTPRequest,
        upstreamOrigin: URL,
        pathPrefix: String
    ) -> URL? {
        let pathOnly = KawarimiRequestPath.pathOnly(request.path ?? "")
        let aligned = KawarimiPath.aligned(path: pathOnly, pathPrefix: pathPrefix)
        var components = URLComponents()
        components.scheme = upstreamOrigin.scheme
        components.host = upstreamOrigin.host
        components.port = upstreamOrigin.port
        components.percentEncodedPath = aligned
        if let query = queryString(from: request.path ?? "") {
            components.percentEncodedQuery = query
        }
        return components.url
    }

    private static func applyForwardedHeaders(_ fields: HTTPFields, to request: inout URLRequest) {
        for field in fields {
            request.addValue(field.value, forHTTPHeaderField: field.name.rawName)
        }
    }

    private func logForwardFailure(_ error: any Error) {
        guard proxyDebug else { return }
        let message = "Upstream forward failed: \(error.localizedDescription)"
#if canImport(OSLog)
        kawarimiProxyForwarderLog.debug("\(message, privacy: .public)")
#else
        StandardError.write("KawarimiProxy: \(message)")
#endif
    }

    private static func queryString(from rawPath: String) -> String? {
        guard let queryStart = rawPath.firstIndex(of: "?") else { return nil }
        let afterQuery = rawPath[rawPath.index(after: queryStart)...]
        if let fragmentStart = afterQuery.firstIndex(of: "#") {
            return String(afterQuery[..<fragmentStart])
        }
        return String(afterQuery)
    }

    private static func badGatewayResponse(message: String) -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: .init(code: 502))
        response.headerFields[.contentType] = "text/plain; charset=utf-8"
        return (response, HTTPBody(message))
    }

    private static func payloadTooLargeResponse(limit: Int) -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: .init(code: 413))
        response.headerFields[.contentType] = "text/plain; charset=utf-8"
        return (response, HTTPBody("Request body exceeds \(limit) bytes"))
    }
}
