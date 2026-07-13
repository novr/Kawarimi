#if os(Linux) || os(macOS)
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct LoopbackHTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

struct LoopbackHTTPResponse: Sendable {
    let status: Int
    let headers: [String: String]
    let body: Data

    init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

/// Minimal loopback HTTP/1.1 server for transport integration tests.
final class LoopbackHTTPServer: @unchecked Sendable {
    enum ServerError: Error, Sendable {
        case socketCreateFailed
        case bindFailed
        case listenFailed
        case portUnavailable
    }

    private let socketFD: Int32
    let port: Int
    private var serveTask: Task<Void, Never>?
    private let acceptGate = LoopbackAcceptGate()

    private init(socketFD: Int32, port: Int) {
        self.socketFD = socketFD
        self.port = port
    }

    var origin: URL { URL(string: "http://127.0.0.1:\(port)")! }

    static func start() throws -> LoopbackHTTPServer {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ServerError.socketCreateFailed }
        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        var addr = sockaddr_in()
        #if os(macOS)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw ServerError.bindFailed
        }
        guard listen(fd, SOMAXCONN) == 0 else {
            close(fd)
            throw ServerError.listenFailed
        }
        var bound = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &bound) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard nameResult == 0 else {
            close(fd)
            throw ServerError.portUnavailable
        }
        let port = Int(UInt16(bigEndian: bound.sin_port))
        return LoopbackHTTPServer(socketFD: fd, port: port)
    }

    func run(handler: @escaping @Sendable (LoopbackHTTPRequest) -> LoopbackHTTPResponse) {
        serveTask?.cancel()
        let fd = socketFD
        let gate = acceptGate
        serveTask = Task.detached {
            await gate.signalReady()
            while !Task.isCancelled {
                let client = accept(fd, nil, nil)
                guard client >= 0 else { continue }
                defer { close(client) }
                guard let request = Self.readRequest(from: client) else { continue }
                let response = handler(request)
                Self.writeResponse(response, to: client)
            }
        }
    }

    func waitUntilAccepting() async {
        await acceptGate.waitUntilReady()
    }

    func stop() {
        serveTask?.cancel()
        serveTask = nil
        close(socketFD)
    }

    private static func readRequest(from client: Int32) -> LoopbackHTTPRequest? {
        var buffer = Data()
        var headerEnd: Int?
        while headerEnd == nil {
            var chunk = [UInt8](repeating: 0, count: 4096)
            let readCount = recv(client, &chunk, chunk.count, 0)
            guard readCount > 0 else { return nil }
            buffer.append(contentsOf: chunk.prefix(readCount))
            if let range = buffer.range(of: Data([13, 10, 13, 10])) {
                headerEnd = range.upperBound
            }
            if buffer.count > 1_048_576 { return nil }
        }
        guard let headerEnd else { return nil }
        let headerData = buffer.prefix(headerEnd)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        var body = Data(buffer.suffix(from: headerEnd))
        if let lengthRaw = headers["content-length"], let length = Int(lengthRaw), body.count < length {
            var remaining = length - body.count
            while remaining > 0 {
                var chunk = [UInt8](repeating: 0, count: min(remaining, 4096))
                let readCount = recv(client, &chunk, chunk.count, 0)
                guard readCount > 0 else { break }
                body.append(contentsOf: chunk.prefix(readCount))
                remaining -= readCount
            }
        }
        return LoopbackHTTPRequest(method: method, path: path, headers: headers, body: body)
    }

    private static func writeResponse(_ response: LoopbackHTTPResponse, to client: Int32) {
        let phrase = HTTPURLResponse.localizedString(forStatusCode: response.status)
        var headerLines = ["HTTP/1.1 \(response.status) \(phrase)"]
        var headers = response.headers
        if headers["content-length"] == nil {
            headers["Content-Length"] = "\(response.body.count)"
        }
        for (name, value) in headers {
            headerLines.append("\(name): \(value)")
        }
        var data = Data((headerLines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
        data.append(response.body)
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var sent = 0
            while sent < raw.count {
                let wrote = send(client, base.advanced(by: sent), raw.count - sent, 0)
                guard wrote > 0 else { return }
                sent += wrote
            }
        }
    }
}

private actor LoopbackAcceptGate {
    private var ready = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signalReady() {
        ready = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }

    func waitUntilReady() async {
        if ready { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
#endif
