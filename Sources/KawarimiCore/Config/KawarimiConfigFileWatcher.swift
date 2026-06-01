import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Watches a config file path (or its parent directory until the file exists) and invokes `onChange` after debounced writes.
final class KawarimiConfigFileWatcher: @unchecked Sendable {
    private let targetPath: String
    private let debounceInterval: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "dev.kawarimi.config-file-watcher")
    private let lock = NSLock()
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private var watchingDirectory = false

    init(path: String, debounceInterval: TimeInterval = 0.2, onChange: @escaping @Sendable () -> Void) {
        self.targetPath = path
        self.debounceInterval = debounceInterval
        self.onChange = onChange
        queue.async { [self] in
            self.installWatch()
        }
    }

    func cancel() {
        queue.sync {
            cancelLocked()
        }
    }

    private func installWatch() {
        cancelLocked()
        if FileManager.default.fileExists(atPath: targetPath) {
            watchFile(at: targetPath)
        } else {
            watchParentDirectory()
        }
    }

    private func watchFile(at path: String) {
        let fd = open(path, watchOpenFlags)
        guard fd >= 0 else {
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
            self?.scheduleReload()
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
        let fd = open(directory, watchOpenFlags)
        guard fd >= 0 else { return }
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
            if FileManager.default.fileExists(atPath: self.targetPath) {
                self.installWatch()
            }
            self.scheduleReload()
        }
        source.setCancelHandler { [fd] in
            close(fd)
        }
        self.source = source
        source.resume()
    }

    private func scheduleReload() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [onChange] in
            onChange()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func cancelLocked() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
        fileDescriptor = -1
        watchingDirectory = false
    }
}

#if os(Linux)
private let watchOpenFlags: Int32 = O_RDONLY
#else
private let watchOpenFlags: Int32 = O_EVTONLY
#endif
