import Foundation
@testable import KawarimiCore
import Testing

@Suite("KawarimiConfigFileWatcher", .timeLimit(.minutes(1)))
struct KawarimiConfigFileWatcherTests {
    @Test func fileWrite_triggersDebouncedCallback() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let gate = AsyncStream<Void>.makeStream()
        let watcher = KawarimiConfigFileWatcher(path: url.path, debounceInterval: 0.05) {
            gate.continuation.yield()
        }
        defer { watcher.cancel() }

        try await Task.sleep(for: .milliseconds(50))
        let data = try JSONEncoder().encode(KawarimiConfig(overrides: []))
        try data.write(to: url, options: .atomic)

        #expect(await waitForEvent(gate.stream, timeout: .seconds(2)))
    }

    @Test func storeFileWatch_appliesExternalEdit() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = try KawarimiConfigStore(configPath: url.path)
        await store.startFileWatchIfEnabled(policy: .enabled)

        try await Task.sleep(for: .milliseconds(50))
        let onDisk = [
            MockOverride(
                path: "/pets",
                method: .get,
                statusCode: 200,
                body: "{\"watched\":true}",
                contentType: "application/json"
            ),
        ]
        let data = try JSONEncoder().encode(KawarimiConfig(overrides: onDisk))
        try data.write(to: url, options: .atomic)

        try await expectEventually(timeout: .seconds(2)) {
            await store.overrides() == onDisk
        }
        await store.stopFileWatch()
    }

    @Test func startFileWatchIfEnabled_respectsDisabledPolicy() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = try KawarimiConfigStore(configPath: url.path)
        await store.startFileWatchIfEnabled(policy: .disabled)

        let data = try JSONEncoder().encode(
            KawarimiConfig(
                overrides: [
                    MockOverride(
                        path: "/x",
                        method: .get,
                        statusCode: 200,
                        body: "{}",
                        contentType: "application/json"
                    ),
                ]
            )
        )
        try data.write(to: url, options: .atomic)
        try await Task.sleep(for: .milliseconds(300))

        #expect(await store.overrides().isEmpty)
    }

    private func waitForEvent(
        _ stream: AsyncStream<Void>,
        timeout: Duration
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in stream {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    private func expectEventually(
        timeout: Duration,
        poll: Duration = .milliseconds(25),
        _ condition: @escaping () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: poll)
        }
        Issue.record("Condition not met before timeout")
    }

    // MARK: - inotify name decoding

    @Test func decodeInotifyName_stripsNulPaddingBeyondTerminator() {
        // inotify pads the name field with NULs up to the record-declared length; the
        // declared length is larger than the actual name + single terminator.
        let name = Array("kawarimi.json".utf8)
        let declaredLength = 16 // name is 13 bytes, padded with 3 trailing NULs
        var field = name
        field.append(contentsOf: [UInt8](repeating: 0, count: declaredLength - name.count))
        #expect(decodeInotifyEventName(field, declaredLength: declaredLength) == "kawarimi.json")
    }

    @Test func decodeInotifyName_handlesSingleTerminatorAndEmpty() {
        let name = Array("a.json".utf8) + [0]
        #expect(decodeInotifyEventName(name, declaredLength: name.count) == "a.json")
        #expect(decodeInotifyEventName([UInt8](repeating: 0, count: 8), declaredLength: 8) == nil)
        #expect(decodeInotifyEventName([UInt8](), declaredLength: 0) == nil)
    }
}
