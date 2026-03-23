import AppKit
import DemoAPI
import Foundation
import KawarimiCore
import SwiftUI

/// Spec に沿って URL・クエリ・ボディを組み立て任意メソッドで HTTP を送る（GET 専用ではない）。
struct OpenAPIExecuteView: View {
    @Binding var serverBaseURL: String
    @Binding var apiPathPrefix: String

    @State private var operationId: String = KawarimiSpec.endpoints.first?.operationId ?? ""
    @State private var pathParams: [String: String] = [:]
    @State private var queryString: String = ""
    @State private var bodyText: String = "{}"
    @State private var resultText: String = ""
    @State private var isRunning = false

    private var endpoints: [KawarimiSpec.Endpoint] { KawarimiSpec.endpoints }

    private var clientURL: URL? {
        ServerURLNormalization.clientURL(
            serverBaseURL: serverBaseURL,
            apiPathPrefix: apiPathPrefix,
            meta: KawarimiSpec.meta
        )
    }

    private var endpoint: KawarimiSpec.Endpoint? {
        endpoints.first { $0.operationId == operationId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAPI の実行")
                .font(.headline)
            HStack {
                Text("Server URL:")
                TextField(KawarimiSpec.meta.serverURL, text: $serverBaseURL)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("API prefix:")
                TextField(KawarimiSpec.meta.apiPathPrefix, text: $apiPathPrefix)
                    .textFieldStyle(.roundedBorder)
            }
            Text("実際のベース: \(clientURL?.absoluteString ?? "（無効）")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Operation", selection: $operationId) {
                ForEach(endpoints, id: \.operationId) { ep in
                    Text("\(ep.method)  \(ep.operationId)")
                        .tag(ep.operationId)
                }
            }
            .onChange(of: operationId) { _, _ in
                syncOperationInputs()
            }

            if let ep = endpoint {
                let names = bracedParamNames(in: ep.path)
                if !names.isEmpty {
                    Text("パスパラメータ")
                        .font(.subheadline)
                    ForEach(names, id: \.self) { name in
                        HStack {
                            Text("\(name):")
                            TextField(name, text: paramBinding(name))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                HStack {
                    Text("Query (任意):")
                    TextField("limit=20&offset=0", text: $queryString)
                        .textFieldStyle(.roundedBorder)
                }

                if HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: ep.method) {
                    Text("Request body (JSON)")
                        .font(.subheadline)
                    TextEditor(text: $bodyText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .border(Color.secondary.opacity(0.3))
                }
            }

            Button("実行") {
                Task { await performRequest() }
            }
            .disabled(clientURL == nil || isRunning || endpoint == nil)

            if isRunning {
                ProgressView()
            }
            if !resultText.isEmpty {
                ScrollView {
                    Text(resultText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(8)
                }
                .frame(maxHeight: 280)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 320)
        .onAppear {
            if operationId.isEmpty, let first = endpoints.first?.operationId {
                operationId = first
            }
            syncOperationInputs()
        }
    }

    private func paramBinding(_ name: String) -> Binding<String> {
        Binding(
            get: { pathParams[name, default: ""] },
            set: { pathParams[name] = $0 }
        )
    }

    private func syncOperationInputs() {
        guard let ep = endpoint else { return }
        let names = bracedParamNames(in: ep.path)
        var next: [String: String] = [:]
        for n in names {
            next[n] = pathParams[n] ?? "item-1"
        }
        pathParams = next

        if HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: ep.method) {
            let sample = ep.responses.filter { $0.statusCode < 400 }.first?.body
            bodyText = (sample?.isEmpty == false) ? (sample ?? "{}") : "{}"
        } else {
            bodyText = ""
        }
        queryString = ""
    }

    private func performRequest() async {
        guard let base = clientURL, let ep = endpoint else { return }

        isRunning = true
        resultText = ""
        defer { isRunning = false }

        let metaPathPrefix = OpenAPIPathPrefix.normalizedPrefix(KawarimiSpec.meta.apiPathPrefix)
        var path = ep.path
        if path.hasPrefix(metaPathPrefix) {
            path = String(path.dropFirst(metaPathPrefix.count))
        }
        if path.isEmpty {
            path = "/"
        }
        if !path.hasPrefix("/") {
            path = "/" + path
        }

        for name in bracedParamNames(in: path) {
            let raw = pathParams[name] ?? ""
            let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
            path = path.replacingOccurrences(of: "{\(name)}", with: encoded)
        }

        if path.contains("{") {
            resultText = "Error: パスに未置換の `{…}` があります（パスパラメータを入力してください）"
            return
        }

        guard var url = append(base: base, path: path) else {
            resultText = "Error: URL の組み立てに失敗しました"
            return
        }

        let q = queryString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            parts?.query = q
            if let u = parts?.url { url = u }
        }

        let bodyData = bodyText.data(using: .utf8)
        let withBody = HTTPRequestBodyPolicy.shouldAttachRequestBody(method: ep.method, body: bodyData)

        var request = URLRequest(url: url)
        request.httpMethod = ep.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if withBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        } else {
            request.httpBody = nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse).map { "\($0.statusCode)" } ?? "?"
            let bodyOut: String
            if let s = String(data: data, encoding: .utf8), !s.isEmpty {
                bodyOut = s
            } else if data.isEmpty {
                bodyOut = "(empty body)"
            } else {
                bodyOut = data.map { String(format: "%02x", $0) }.joined(separator: " ")
            }
            resultText = "HTTP \(status)\n\(bodyOut)"
        } catch {
            resultText = "Error: \(error.localizedDescription)"
        }
    }

    private func bracedParamNames(in path: String) -> [String] {
        let pattern = #"\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(path.startIndex..., in: path)
        return regex.matches(in: path, range: range).compactMap {
            guard let r = Range($0.range(at: 1), in: path) else { return nil }
            return String(path[r])
        }
    }

    private func append(base: URL, path: String) -> URL? {
        var tail = path
        if tail.hasPrefix("/") {
            tail = String(tail.dropFirst())
        }
        if tail.isEmpty {
            return base
        }
        var u = base
        for segment in tail.split(separator: "/") {
            u = u.appendingPathComponent(String(segment), isDirectory: false)
        }
        return u
    }
}
