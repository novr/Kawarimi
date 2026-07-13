import Foundation
import HTTPTypes
import KawarimiCore
import OpenAPIRuntime

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Raw HTTP forward from Proxy `ServerMiddleware` to an upstream origin.
public struct KawarimiUpstreamHTTPForwarder: Sendable {
    public typealias URLSessionSend = @Sendable (URLRequest, HTTPBody?) async throws -> (HTTPURLResponse, HTTPBody?)

    private let upstreamOrigin: URL
    private let sessionSend: URLSessionSend

    public init(upstreamOrigin: URL, session: URLSession = .shared) {
        self.upstreamOrigin = upstreamOrigin
        self.sessionSend = Self.makeDefaultSessionSend(session: session)
    }

    init(upstreamOrigin: URL, sessionSend: @escaping URLSessionSend) {
        self.upstreamOrigin = upstreamOrigin
        self.sessionSend = sessionSend
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

        let forwardedHeaders = KawarimiProxyHeaders.forwardingRequestHeaders(from: request.headerFields)
        for field in forwardedHeaders {
            urlRequest.setValue(field.value, forHTTPHeaderField: field.name.rawName)
        }

        do {
            let (http, responseBody) = try await sessionSend(urlRequest, body)
            var response = HTTPResponse(status: .init(code: http.statusCode))
            for (name, value) in http.allHeaderFields {
                guard let name = name as? String, let value = value as? String else { continue }
                guard let fieldName = HTTPField.Name(name) ?? HTTPField.Name(name.lowercased()) else { continue }
                response.headerFields.append(HTTPField(name: fieldName, value: value))
            }
            response.headerFields = KawarimiProxyHeaders.forwardingResponseHeaders(from: response.headerFields)
            return (response, responseBody)
        } catch {
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

    private static func makeDefaultSessionSend(session: URLSession) -> URLSessionSend {
        { urlRequest, body in
            let urlResponse: URLResponse
            let responseBody: HTTPBody?
            if let body, !isEmptyBody(body) {
                let bodyData = try await uploadBodyData(from: body)
                let (data, response) = try await session.upload(for: urlRequest, from: bodyData)
                urlResponse = response
                responseBody = data.isEmpty ? nil : HTTPBody(data)
            } else {
                let (data, response) = try await session.data(for: urlRequest)
                urlResponse = response
                responseBody = data.isEmpty ? nil : HTTPBody(data)
            }
            guard let http = urlResponse as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (http, responseBody)
        }
    }

    private static func isEmptyBody(_ body: HTTPBody) -> Bool {
        if case .known(0) = body.length { return true }
        return false
    }

    private static func uploadBodyData(from body: HTTPBody) async throws -> Data {
        let upTo: Int = switch body.length {
        case .known(let length): Int(length)
        case .unknown: .max
        }
        return try await Data(collecting: body, upTo: upTo)
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
}
