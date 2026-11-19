import Foundation
import KawarimiCore
import OpenAPIRuntime

/// Copies up to 1 MiB of the bytes a downstream consumer actually reads, without buffering ahead of it.
final class KawarimiHTTPBodyPrefixObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let maxBytes: Int

    init(maxBytes: Int = KawarimiRequestHistoryCapture.maxBodyUTF8Bytes) {
        self.maxBytes = maxBytes
    }

    func observe(_ chunk: ArraySlice<UInt8>) {
        lock.lock()
        defer { lock.unlock() }
        guard buffer.count < maxBytes else { return }
        buffer.append(contentsOf: chunk.prefix(maxBytes - buffer.count))
    }

    /// A body that supports multiple iterations is observed per pass, so a re-read must not append to the previous pass.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll(keepingCapacity: true)
    }

    func capturedBody() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return KawarimiRequestHistoryCapture.utf8Prefix(from: buffer, maxBytes: maxBytes)
    }

    /// Wraps `body` keeping its length and iteration behavior; bytes are observed only as the consumer pulls them.
    static func tee(_ body: HTTPBody?) -> (HTTPBody?, KawarimiHTTPBodyPrefixObserver?) {
        guard let body else { return (nil, nil) }
        let observer = KawarimiHTTPBodyPrefixObserver()
        let observed = ObservedSequence(base: body, observer: observer)
        return (
            HTTPBody(observed, length: body.length, iterationBehavior: body.iterationBehavior),
            observer
        )
    }

    private struct ObservedSequence: AsyncSequence, Sendable {
        typealias Element = ArraySlice<UInt8>

        let base: HTTPBody
        let observer: KawarimiHTTPBodyPrefixObserver

        struct AsyncIterator: AsyncIteratorProtocol {
            var base: HTTPBody.AsyncIterator
            let observer: KawarimiHTTPBodyPrefixObserver

            mutating func next() async throws -> ArraySlice<UInt8>? {
                let chunk = try await base.next()
                if let chunk {
                    observer.observe(chunk)
                }
                return chunk
            }
        }

        func makeAsyncIterator() -> AsyncIterator {
            observer.reset()
            return AsyncIterator(base: base.makeAsyncIterator(), observer: observer)
        }
    }
}
