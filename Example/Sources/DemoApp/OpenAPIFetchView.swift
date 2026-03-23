import AppKit
import DemoAPI
import Foundation
import KawarimiCore
import SwiftUI

/// OpenAPI の手動実行。`KawarimiSpec.endpoints`（`openapi.yaml` から生成）に追随する。
struct OpenAPIFetchView: View {
    @Binding var serverBaseURL: String
    @Binding var apiPathPrefix: String

    @State private var selectedOperationId: String = KawarimiSpec.endpoints.first?.operationId ?? ""
    @State private var pathParams: [String: String] = [:]
    @State private var queryString: String = ""
    @State private var bodyText: String = "{}"
    @State private var resultText: String = ""
    @State private var isRunning = false

    private var endpoints: [KawarimiSpec.Endpoint] { KawarimiSpec.endpoints }

    private var defaultServerBasePlaceholder: String {
        ServerURLNormalization.defaultServerBaseURLString(
            openAPIServerURL: KawarimiSpec.meta.serverURL,
            apiPathPrefix: KawarimiSpec.meta.apiPathPrefix
        )
    }

    private var parsedOpenAPIBaseURL: URL? {
        ServerURLNormalization.openAPIClientBaseURL(serverBase: serverBaseURL, apiPathPrefix: apiPathPrefix)
    }

    private var currentEndpoint: KawarimiSpec.Endpoint? {
        endpoints.first { $0.operationId == selectedOperationId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAPI の実行")
                .font(.headline)
            HStack {
                Text("Server URL:")
                TextField(defaultServerBasePlaceholder, text: $serverBaseURL)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("API prefix:")
                TextField(KawarimiSpec.meta.apiPathPrefix, text: $apiPathPrefix)
                    .textFieldStyle(.roundedBorder)
            }
            Text("実際のベース: \(parsedOpenAPIBaseURL?.absoluteString ?? "（無効）")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Operation", selection: $selectedOperationId) {
                ForEach(endpoints, id: \.operationId) { ep in
                    Text("\(ep.method)  \(ep.operationId)")
                        .tag(ep.operationId)
                }
            }
            .onChange(of: selectedOperationId) { _, _ in
                syncInputsToSelection()
            }

            if let ep = currentEndpoint {
                let names = pathParameterNames(in: ep.path)
                if !names.isEmpty {
                    Text("パスパラメータ")
                        .font(.subheadline)
                    ForEach(names, id: \.self) { name in
                        HStack {
                            Text("\(name):")
                            TextField(name, text: binding(forPathParam: name))
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
                Task { await fetch() }
            }
            .disabled(parsedOpenAPIBaseURL == nil || isRunning || currentEndpoint == nil)

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
            if selectedOperationId.isEmpty, let first = endpoints.first?.operationId {
                selectedOperationId = first
            }
            syncInputsToSelection()
        }
    }

    private func binding(forPathParam name: String) -> Binding<String> {
        Binding(
            get: { pathParams[name, default: ""] },
            set: { pathParams[name] = $0 }
        )
    }

    /// `openapi.yaml` 更新後も `KawarimiSpec` を再生成すれば一覧は追従する。
    private func syncInputsToSelection() {
        guard let ep = currentEndpoint else { return }
        let names = pathParameterNames(in: ep.path)
        var next: [String: String] = [:]
        for n in names {
            next[n] = pathParams[n] ?? "item-1"
        }
        pathParams = next

        if HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: ep.method) {
            let example = ep.responses.filter { $0.statusCode < 400 }.first?.body
            bodyText = (example?.isEmpty == false) ? (example ?? "{}") : "{}"
        } else {
            bodyText = ""
        }
        queryString = ""
    }

    private func fetch() async {
        guard let base = parsedOpenAPIBaseURL,
              let ep = currentEndpoint else { return }

        isRunning = true
        resultText = ""
        defer { isRunning = false }

        let prefix = OpenAPIPathPrefix.normalizedPrefix(KawarimiSpec.meta.apiPathPrefix, defaultIfEmpty: "/api")
        var pathForSubst = ep.path
        if pathForSubst.hasPrefix(prefix) {
            pathForSubst = String(pathForSubst.dropFirst(prefix.count))
        }
        if pathForSubst.isEmpty {
            pathForSubst = "/"
        }
        if !pathForSubst.hasPrefix("/") {
            pathForSubst = "/" + pathForSubst
        }

        for name in pathParameterNames(in: pathForSubst) {
            let raw = pathParams[name] ?? ""
            let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
            pathForSubst = pathForSubst.replacingOccurrences(of: "{\(name)}", with: encoded)
        }

        if pathForSubst.contains("{") {
            resultText = "Error: パスに未置換の `{…}` があります（パスパラメータを入力してください）"
            return
        }

        guard var url = appendPath(base: base, relativePath: pathForSubst) else {
            resultText = "Error: URL の組み立てに失敗しました"
            return
        }

        let q = queryString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
            c?.query = q
            if let u = c?.url { url = u }
        }

        let bodyData = bodyText.data(using: .utf8)
        let attachBody = HTTPRequestBodyPolicy.shouldAttachRequestBody(method: ep.method, bodyUTF8: bodyData)

        var request = URLRequest(url: url)
        request.httpMethod = ep.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if attachBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        } else {
            request.httpBody = nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse).map { "\($0.statusCode)" } ?? "?"
            let bodyString: String
            if let s = String(data: data, encoding: .utf8), !s.isEmpty {
                bodyString = s
            } else if data.isEmpty {
                bodyString = "(empty body)"
            } else {
                bodyString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
            }
            resultText = "HTTP \(status)\n\(bodyString)"
        } catch {
            resultText = "Error: \(error.localizedDescription)"
        }
    }

    private func pathParameterNames(in path: String) -> [String] {
        let pattern = #"\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(path.startIndex..., in: path)
        return regex.matches(in: path, range: range).compactMap {
            guard let r = Range($0.range(at: 1), in: path) else { return nil }
            return String(path[r])
        }
    }

    private func appendPath(base: URL, relativePath: String) -> URL? {
        var tail = relativePath
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
