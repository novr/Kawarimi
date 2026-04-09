#if os(macOS)
import AppKit
import DemoAPI
import KawarimiCore
import KawarimiHenge
import SwiftUI

private final class HengeCliAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private struct HengeCliRootView: View {
    var body: some View {
        if let url = HengeCliConfig.clientBaseURL {
            KawarimiConfigView(client: KawarimiAPIClient(baseURL: url), specType: SpecResponse.self)
        } else {
            ContentUnavailableView(
                "Invalid server URL",
                systemImage: "exclamationmark.triangle",
                description: Text("Check `servers` in openapi.yaml and regenerate.")
            )
        }
    }
}

@main
struct HengeCliApp: App {
    @NSApplicationDelegateAdaptor(HengeCliAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Kawarimi Henge") {
            HengeCliRootView()
        }
        .defaultSize(width: 960, height: 720)
    }
}
#else
import Darwin

/// Henge UI is macOS-only; this stub keeps `swift package` resolving on iOS.
@main
enum HengeCli {
    static func main() {
        fputs("HengeCli runs on macOS only.\n", stderr)
        exit(1)
    }
}
#endif
