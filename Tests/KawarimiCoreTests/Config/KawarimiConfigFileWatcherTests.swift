import Foundation
@testable import KawarimiCore
import Testing

@Suite("KawarimiConfigFileWatcher")
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

    @Test func storeFileWatch_appliesAtomicReplaceOfPreexistingFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        // File already exists when the watcher starts → Darwin watches the file's inode directly.
        let initial = [
            MockOverride(path: "/pets", method: .get, statusCode: 200, body: "{\"v\":1}", contentType: "application/json"),
        ]
        let initialData = try JSONEncoder().encode(KawarimiConfig(overrides: initial))
        try initialData.write(to: url, options: .atomic)

        let store = try KawarimiConfigStore(configPath: url.path)
        #expect(await store.overrides() == initial)
        await store.startFileWatchIfEnabled(policy: .enabled)

        try await Task.sleep(for: .milliseconds(50))
        // Atomic rename-over replaces the inode the watcher's fd points at.
        let updated = [
            MockOverride(path: "/pets", method: .get, statusCode: 200, body: "{\"v\":2}", contentType: "application/json"),
        ]
        let updatedData = try JSONEncoder().encode(KawarimiConfig(overrides: updated))
        try updatedData.write(to: url, options: .atomic)

        try await expectEventually(timeout: .seconds(5)) {
            await store.overrides() == updated
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
}
