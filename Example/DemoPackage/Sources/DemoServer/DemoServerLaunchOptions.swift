#if os(macOS)
import Foundation

struct DemoServerLaunchOptions {
    var listenReadyFile: String?
    var printListenURLToStdout: Bool

    static func parse(arguments: [String] = CommandLine.arguments) -> DemoServerLaunchOptions {
        var args = Array(arguments.dropFirst())
        var options = DemoServerLaunchOptions(
            listenReadyFile: ProcessInfo.processInfo.environment["KAWARIMI_LISTEN_READY_FILE"],
            printListenURLToStdout: false
        )

        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "--print-listen-url":
                if let next = args.first, !next.hasPrefix("-") {
                    options.listenReadyFile = args.removeFirst()
                } else {
                    options.printListenURLToStdout = true
                }
            case "--listen-ready-file":
                if let next = args.first, !next.hasPrefix("-") {
                    options.listenReadyFile = args.removeFirst()
                }
            case let flag where flag.hasPrefix("--print-listen-url="):
                options.listenReadyFile = String(flag.dropFirst("--print-listen-url=".count))
            case let flag where flag.hasPrefix("--listen-ready-file="):
                options.listenReadyFile = String(flag.dropFirst("--listen-ready-file=".count))
            default:
                break
            }
        }

        return options
    }
}
#endif
