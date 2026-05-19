#if os(macOS) || os(Linux)
import Foundation
import Vapor

struct ListenReadyNotifier: LifecycleHandler {
    let readyFilePath: String?
    let printToStdout: Bool

    func didBoot(_ application: Application) throws {
        let readyFilePath = readyFilePath
        let printToStdout = printToStdout
        Task {
            await Self.writeWhenBound(
                application: application,
                readyFilePath: readyFilePath,
                printToStdout: printToStdout
            )
        }
    }

    private static func writeWhenBound(
        application: Application,
        readyFilePath: String?,
        printToStdout: Bool
    ) async {
        for _ in 0..<500 {
            let port = application.http.server.configuration.port
            if port > 0 {
                let hostname = application.http.server.configuration.hostname
                let listenURL = "http://\(hostname):\(port)"
                if printToStdout {
                    print(listenURL)
                }
                if let readyFilePath {
                    writeListenURL(listenURL, to: readyFilePath)
                }
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func writeListenURL(_ listenURL: String, to readyFilePath: String) {
        let fileURL = URL(fileURLWithPath: readyFilePath)
        let parent = fileURL.deletingLastPathComponent()
        if !parent.path.isEmpty {
            try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try? Data((listenURL + "\n").utf8).write(to: fileURL, options: .atomic)
    }
}
#endif
