import Foundation
import KawarimiCore
import OpenAPIRuntime

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum KawarimiProxyForwardError: Error, Sendable {
    case bodyTooLarge(limit: Int)
    case responseTooLarge(limit: Int)
}

struct KawarimiProxyURLSessionTransport: Sendable {
    private let sendRequest: @Sendable (URLRequest, HTTPBody?) async throws -> (HTTPURLResponse, HTTPBody?)

    fileprivate init(sendRequest: @escaping @Sendable (URLRequest, HTTPBody?) async throws -> (HTTPURLResponse, HTTPBody?)) {
        self.sendRequest = sendRequest
    }

    static func live() -> KawarimiProxyURLSessionTransport {
        #if os(Linux)
        KawarimiProxyBufferedURLSessionTransport.makeTransport()
        #else
        KawarimiProxyStreamingURLSessionTransport.makeTransport()
        #endif
    }

    static func mock(
        _ handler: @escaping @Sendable (URLRequest, HTTPBody?) async throws -> (HTTPURLResponse, HTTPBody?)
    ) -> KawarimiProxyURLSessionTransport {
        KawarimiProxyURLSessionTransport(sendRequest: handler)
    }

    func send(_ request: URLRequest, body: HTTPBody?) async throws -> (HTTPURLResponse, HTTPBody?) {
        try await sendRequest(request, body)
    }
}

enum KawarimiProxyRequestBody {
    static func isEmpty(_ body: HTTPBody) -> Bool {
        if case .known(0) = body.length { return true }
        return false
    }

    static func materializeToTemporaryFile(_ body: HTTPBody) async throws -> URL {
        let maxBytes = KawarimiProxyForwardLimits.maxRequestBodyBytes
        if case .known(let length) = body.length, length > maxBytes {
            throw KawarimiProxyForwardError.bodyTooLarge(limit: maxBytes)
        }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kawarimi-proxy-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            try? FileManager.default.removeItem(at: fileURL)
            throw URLError(.cannotCreateFile)
        }
        defer { try? handle.close() }
        var total = 0
        do {
            for try await chunk in body {
                total += chunk.count
                if total > maxBytes {
                    throw KawarimiProxyForwardError.bodyTooLarge(limit: maxBytes)
                }
                if !chunk.isEmpty {
                    try handle.write(contentsOf: chunk)
                }
            }
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
    }

    static func attachStreamingBody(to request: inout URLRequest, fileURL: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let sizeNumber = attributes[.size] as? NSNumber else {
            throw URLError(.cannotOpenFile)
        }
        let size = sizeNumber.intValue
        if size == 0 { return }
        guard let stream = InputStream(url: fileURL) else {
            throw URLError(.cannotOpenFile)
        }
        request.httpBodyStream = stream
        request.setValue("\(size)", forHTTPHeaderField: "Content-Length")
    }
}

enum KawarimiProxyResponseBodyPolicy {
    static func declaredBodyLength(_ response: HTTPURLResponse) -> Int? {
        if let raw = response.value(forHTTPHeaderField: "Content-Length"),
            let parsed = Int(raw),
            parsed >= 0
        {
            return parsed
        }
        let expected = response.expectedContentLength
        if expected > 0 { return Int(expected) }
        return nil
    }
}

private enum KawarimiProxyURLSessionTransportCore {
    static func makeSession() -> URLSession {
        #if os(Linux)
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
        #else
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
        #endif
    }

    static func isHeadRequest(_ request: URLRequest) -> Bool {
        request.httpMethod?.uppercased() == "HEAD"
    }

    static func isNoBodyStatus(_ statusCode: Int) -> Bool {
        statusCode == 204 || statusCode == 304
    }

    static func attachRequestBody(_ body: HTTPBody, to request: inout URLRequest) async throws -> URL? {
        let fileURL = try await KawarimiProxyRequestBody.materializeToTemporaryFile(body)
        #if os(Linux)
        let data = try Data(contentsOf: fileURL)
        if !data.isEmpty {
            request.httpBody = data
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        }
        #else
        try KawarimiProxyRequestBody.attachStreamingBody(to: &request, fileURL: fileURL)
        #endif
        return fileURL
    }
}

#if os(Linux)
private enum KawarimiProxyBufferedURLSessionTransport {
    static func makeTransport() -> KawarimiProxyURLSessionTransport {
        let session = KawarimiProxyURLSessionTransportCore.makeSession()
        return KawarimiProxyURLSessionTransport(sendRequest: { request, body in
            try await send(session: session, request: request, body: body)
        })
    }

    private static func send(
        session: URLSession,
        request: URLRequest,
        body: HTTPBody?
    ) async throws -> (HTTPURLResponse, HTTPBody?) {
        var urlRequest = request
        var tempFileURL: URL?
        if let body {
            tempFileURL = try await KawarimiProxyURLSessionTransportCore.attachRequestBody(body, to: &urlRequest)
        }
        defer {
            if let tempFileURL {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }

        let (data, urlResponse) = try await session.data(for: urlRequest)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let maxResponseBytes = KawarimiProxyForwardLimits.maxResponseBodyBytes
        if let declaredLength = KawarimiProxyResponseBodyPolicy.declaredBodyLength(http),
            declaredLength > maxResponseBytes
        {
            throw KawarimiProxyForwardError.responseTooLarge(limit: maxResponseBytes)
        }

        if KawarimiProxyURLSessionTransportCore.isHeadRequest(urlRequest)
            || KawarimiProxyURLSessionTransportCore.isNoBodyStatus(http.statusCode)
        {
            return (http, nil)
        }

        if data.count > maxResponseBytes {
            throw KawarimiProxyForwardError.responseTooLarge(limit: maxResponseBytes)
        }
        return (http, data.isEmpty ? nil : HTTPBody(data))
    }
}
#else
private enum KawarimiProxyStreamingURLSessionTransport {
    private static let responseChunkSize = 16_384

    static func makeTransport() -> KawarimiProxyURLSessionTransport {
        let session = KawarimiProxyURLSessionTransportCore.makeSession()
        return KawarimiProxyURLSessionTransport(sendRequest: { request, body in
            try await send(session: session, request: request, body: body)
        })
    }

    private static func send(
        session: URLSession,
        request: URLRequest,
        body: HTTPBody?
    ) async throws -> (HTTPURLResponse, HTTPBody?) {
        var urlRequest = request
        var tempFileURL: URL?
        if let body {
            tempFileURL = try await KawarimiProxyURLSessionTransportCore.attachRequestBody(body, to: &urlRequest)
        }
        defer {
            if let tempFileURL {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }

        let (asyncBytes, urlResponse) = try await session.bytes(for: urlRequest)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let maxResponseBytes = KawarimiProxyForwardLimits.maxResponseBodyBytes
        if let declaredLength = KawarimiProxyResponseBodyPolicy.declaredBodyLength(http),
            declaredLength > maxResponseBytes
        {
            try await Self.drain(asyncBytes)
            throw KawarimiProxyForwardError.responseTooLarge(limit: maxResponseBytes)
        }

        if KawarimiProxyURLSessionTransportCore.isHeadRequest(urlRequest)
            || KawarimiProxyURLSessionTransportCore.isNoBodyStatus(http.statusCode)
        {
            try await Self.drain(asyncBytes)
            return (http, nil)
        }

        let responseBody = Self.responseBody(from: asyncBytes, maxBytes: maxResponseBytes)
        return (http, responseBody)
    }

    private static func drain(_ asyncBytes: URLSession.AsyncBytes) async throws {
        var iterator = asyncBytes.makeAsyncIterator()
        while true {
            let chunk = try await readChunk(from: &iterator, upTo: responseChunkSize)
            if chunk.isEmpty { break }
        }
    }

    private static func readChunk(
        from iterator: inout URLSession.AsyncBytes.AsyncIterator,
        upTo maxCount: Int
    ) async throws -> Data {
        var chunk = Data()
        chunk.reserveCapacity(maxCount)
        while chunk.count < maxCount {
            try Task.checkCancellation()
            guard let byte = try await iterator.next() else { break }
            chunk.append(byte)
        }
        return chunk
    }

    private static func responseBody(from asyncBytes: URLSession.AsyncBytes, maxBytes: Int) -> HTTPBody {
        let (stream, continuation) = AsyncThrowingStream<ArraySlice<UInt8>, Error>.makeStream()
        let task = Task {
            do {
                var total = 0
                var iterator = asyncBytes.makeAsyncIterator()
                while true {
                    let chunk = try await readChunk(from: &iterator, upTo: responseChunkSize)
                    guard !chunk.isEmpty else { break }
                    total += chunk.count
                    if total > maxBytes {
                        throw KawarimiProxyForwardError.responseTooLarge(limit: maxBytes)
                    }
                    continuation.yield(ArraySlice(chunk))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return HTTPBody(stream, length: .unknown, iterationBehavior: .single)
    }
}
#endif
