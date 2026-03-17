import DemoAPI
import Foundation
import OpenAPIURLSession
import SwiftUI
#if !os(macOS)
import UIKit
#endif

/// OpenAPI の実行（fetch）画面。getGreeting を呼び出して結果を表示する。
struct OpenAPIFetchView: View {
    @Binding var serverURL: String
    @State private var resultText: String = ""
    @State private var isRunning = false

    private var parsedServerURL: URL? { URL(string: serverURL) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAPI の実行")
                .font(.headline)
            HStack {
                Text("Server URL:")
                TextField("http://localhost:8080/api", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
            }
            Button("Fetch (getGreeting)") {
                Task { await fetch() }
            }
            .disabled(parsedServerURL == nil || isRunning)

            if isRunning {
                ProgressView()
            }
            if !resultText.isEmpty {
                Text(resultText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    #if os(macOS)
                    .background(Color(nsColor: .textBackgroundColor))
                    #else
                    .background(Color(uiColor: .secondarySystemBackground))
                    #endif
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 200)
    }

    private func fetch() async {
        guard let url = parsedServerURL else { return }
        isRunning = true
        resultText = ""
        defer { isRunning = false }
        do {
            let client = Client(serverURL: url, transport: URLSessionTransport())
            let response = try await client.getGreeting(.init())
            switch response {
            case .ok(let ok):
                if case .json(let body) = ok.body {
                    resultText = "OK: \(body.message)"
                } else {
                    resultText = "OK (non-JSON body)"
                }
            default:
                resultText = "\(response)"
            }
        } catch {
            resultText = "Error: \(error.localizedDescription)"
        }
    }
}
