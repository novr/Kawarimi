import Foundation

#if canImport(OSLog)
import OSLog
#endif

#if canImport(OSLog)
private let kawarimiConfigFileWatcherLog = Logger(subsystem: "Kawarimi", category: "KawarimiConfigFileWatcher")
#endif

private func logConfigFileWatchFailure(_ message: String) {
#if canImport(OSLog)
    kawarimiConfigFileWatcherLog.warning("\(message, privacy: .public)")
#else
    StandardError.write("KawarimiConfigFileWatcher: \(message)")
#endif
}

/// Watches a config file path (or its parent directory until the file exists) and invokes `onChange` after debounced writes.
final class KawarimiConfigFileWatcher: @unchecked Sendable {
    private let backend: ConfigFileWatchBackend

    init(path: String, debounceInterval: TimeInterval = 0.2, onChange: @escaping @Sendable () -> Void) {
        backend = ConfigFileWatchBackend(
            targetPath: path,
            debounceInterval: debounceInterval,
            onChange: onChange
        )
        backend.start()
    }

    func cancel() {
        backend.cancel()
    }
}

// MARK: - Backend

private final class ConfigFileWatchBackend: @unchecked Sendable {
    private let targetPath: String
    private let debounceInterval: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "dev.kawarimi.config-file-watcher")
    private var debounceWorkItem: DispatchWorkItem?

    #if os(Linux)
    private var platform: LinuxInotifyWatch?
    #else
    private var platform: DarwinVnodeWatch?
    #endif

    init(targetPath: String, debounceInterval: TimeInterval, onChange: @escaping @Sendable () -> Void) {
        self.targetPath = targetPath
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    func start() {
        queue.sync {
            installPlatformWatch()
        }
    }

    func cancel() {
        queue.sync {
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
            platform?.cancel()
            platform = nil
        }
    }

    private func installPlatformWatch() {
        platform?.cancel()
        #if os(Linux)
        platform = LinuxInotifyWatch(
            targetPath: targetPath,
            queue: queue,
            onEvent: { [weak self] in self?.scheduleReload() },
            onNeedsReinstall: { [weak self] in self?.installPlatformWatch() }
        )
        #else
        platform = DarwinVnodeWatch(
            targetPath: targetPath,
            queue: queue,
            onEvent: { [weak self] in self?.scheduleReload() },
            onNeedsReinstall: { [weak self] in self?.installPlatformWatch() }
        )
        #endif
        platform?.start()
    }

    private func scheduleReload() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [onChange] in
            onChange()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}

#if os(Linux)
import Glibc

private struct InotifyEventHeader {
    var wd: Int32
    var mask: UInt32
    var cookie: UInt32
    var len: UInt32

    static let byteSize = 16
}

private final class LinuxInotifyWatch: @unchecked Sendable {
    private let targetPath: String
    private let targetFileName: String
    private let queue: DispatchQueue
    private let onEvent: () -> Void
    private let onNeedsReinstall: () -> Void
    private var inotifyFD: Int32 = -1
    private var watchDescriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var watchingDirectory = false
    private var targetFileWasPresent = false

    init(targetPath: String, queue: DispatchQueue, onEvent: @escaping () -> Void, onNeedsReinstall: @escaping () -> Void) {
        self.targetPath = targetPath
        self.targetFileName = (targetPath as NSString).lastPathComponent
        self.queue = queue
        self.onEvent = onEvent
        self.onNeedsReinstall = onNeedsReinstall
    }

    func start() {
        targetFileWasPresent = FileManager.default.fileExists(atPath: targetPath)
        if inotifyFD < 0 {
            inotifyFD = inotify_init1(Int32(IN_NONBLOCK | IN_CLOEXEC))
            guard inotifyFD >= 0 else {
                logConfigFileWatchFailure("inotify_init1 failed for \(targetPath)")
                return
            }
            let source = DispatchSource.makeReadSource(fileDescriptor: inotifyFD, queue: queue)
            source.setEventHandler { [weak self] in
                self?.drainEvents()
            }
            source.setCancelHandler { [weak self] in
                guard let self, self.inotifyFD >= 0 else { return }
                close(self.inotifyFD)
                self.inotifyFD = -1
            }
            readSource = source
            source.resume()
        }
        addWatch()
    }

    func cancel() {
        readSource?.cancel()
        readSource = nil
        if watchDescriptor >= 0, inotifyFD >= 0 {
            inotify_rm_watch(inotifyFD, watchDescriptor)
        }
        watchDescriptor = -1
        if inotifyFD >= 0 {
            close(inotifyFD)
            inotifyFD = -1
        }
        targetFileWasPresent = false
    }

    private func addWatch() {
        if watchDescriptor >= 0, inotifyFD >= 0 {
            inotify_rm_watch(inotifyFD, watchDescriptor)
            watchDescriptor = -1
        }
        if FileManager.default.fileExists(atPath: targetPath) {
            watchingDirectory = false
            let mask = UInt32(IN_MODIFY | IN_CLOSE_WRITE | IN_MOVE_SELF | IN_DELETE_SELF)
            watchDescriptor = inotify_add_watch(inotifyFD, targetPath, mask)
        } else {
            watchingDirectory = true
            let parent = (targetPath as NSString).deletingLastPathComponent
            let directory = parent.isEmpty ? "." : parent
            let mask = UInt32(IN_MODIFY | IN_CLOSE_WRITE | IN_CREATE | IN_DELETE | IN_MOVED_TO)
            watchDescriptor = inotify_add_watch(inotifyFD, directory, mask)
        }
        if watchDescriptor < 0 {
            logConfigFileWatchFailure("inotify_add_watch failed for \(targetPath)")
        }
    }

    private func drainEvents() {
        guard inotifyFD >= 0 else { return }
        var needsReinstall = false
        var shouldNotify = false
        let relevantDirectoryMask = UInt32(IN_CREATE | IN_MODIFY | IN_CLOSE_WRITE | IN_MOVED_TO | IN_DELETE)
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while true {
            let count = read(inotifyFD, &buffer, bufferSize)
            if count <= 0 { break }
            var offset = 0
            while offset + InotifyEventHeader.byteSize <= count {
                let mask = buffer.withUnsafeBytes {
                    $0.load(fromByteOffset: offset + 4, as: UInt32.self)
                }
                let len = buffer.withUnsafeBytes {
                    $0.load(fromByteOffset: offset + 12, as: UInt32.self)
                }
                let nameLen = Int(len)
                let recordSize = InotifyEventHeader.byteSize + nameLen
                guard offset + recordSize <= count else { break }

                if watchingDirectory {
                    var nameMatches = false
                    if nameLen > 1 {
                        let nameStart = offset + InotifyEventHeader.byteSize
                        let nameEnd = nameStart + nameLen - 1
                        if nameEnd > nameStart,
                           let name = String(bytes: buffer[nameStart ..< nameEnd], encoding: .utf8),
                           name == targetFileName
                        {
                            nameMatches = true
                        }
                    }
                    if nameMatches, mask & relevantDirectoryMask != 0 {
                        shouldNotify = true
                    }
                    if nameMatches, mask & UInt32(IN_CREATE | IN_MOVED_TO) != 0 {
                        needsReinstall = true
                    }
                } else {
                    shouldNotify = true
                    if mask & UInt32(IN_DELETE_SELF | IN_MOVE_SELF | IN_IGNORED) != 0 {
                        needsReinstall = true
                    }
                }
                offset += recordSize
            }
        }
        if watchingDirectory {
            let filePresent = FileManager.default.fileExists(atPath: targetPath)
            if filePresent, !targetFileWasPresent {
                targetFileWasPresent = true
                shouldNotify = true
                needsReinstall = true
            } else if !filePresent {
                targetFileWasPresent = false
            }
        }
        if needsReinstall {
            onNeedsReinstall()
        }
        if shouldNotify {
            onEvent()
        }
    }
}

#else
import Darwin

private final class DarwinVnodeWatch: @unchecked Sendable {
    private let targetPath: String
    private let queue: DispatchQueue
    private let onEvent: () -> Void
    private let onNeedsReinstall: () -> Void
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var watchingDirectory = false
    private var targetFileWasPresent = false

    init(targetPath: String, queue: DispatchQueue, onEvent: @escaping () -> Void, onNeedsReinstall: @escaping () -> Void) {
        self.targetPath = targetPath
        self.queue = queue
        self.onEvent = onEvent
        self.onNeedsReinstall = onNeedsReinstall
    }

    func start() {
        cancel()
        targetFileWasPresent = FileManager.default.fileExists(atPath: targetPath)
        if targetFileWasPresent {
            watchFile(at: targetPath)
        } else {
            watchParentDirectory()
        }
    }

    func cancel() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
        watchingDirectory = false
        targetFileWasPresent = false
    }

    private func watchFile(at path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            logConfigFileWatchFailure("open(O_EVTONLY) failed for \(path)")
            watchParentDirectory()
            return
        }
        fileDescriptor = fd
        watchingDirectory = false
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.onEvent()
        }
        source.setCancelHandler { [fd] in
            close(fd)
        }
        self.source = source
        source.resume()
    }

    private func watchParentDirectory() {
        let parent = (targetPath as NSString).deletingLastPathComponent
        let directory = parent.isEmpty ? "." : parent
        let fd = open(directory, O_EVTONLY)
        guard fd >= 0 else {
            logConfigFileWatchFailure("open(O_EVTONLY) failed for directory \(directory) (watching \(targetPath))")
            return
        }
        fileDescriptor = fd
        watchingDirectory = true
        let mask: DispatchSource.FileSystemEvent = [.write, .extend, .attrib, .link, .rename, .revoke]
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: mask,
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let filePresent = FileManager.default.fileExists(atPath: self.targetPath)
            if filePresent, !self.targetFileWasPresent {
                self.targetFileWasPresent = true
                self.onNeedsReinstall()
                self.onEvent()
            } else if !filePresent {
                self.targetFileWasPresent = false
            }
        }
        source.setCancelHandler { [fd] in
            close(fd)
        }
        self.source = source
        source.resume()
    }
}
#endif
