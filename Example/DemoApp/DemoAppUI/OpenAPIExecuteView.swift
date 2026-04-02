#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import DemoAPI
import Foundation
import KawarimiCore
import SwiftUI

// MARK: - OpenAPI execute UI

private enum ExecutionTheme {
    #if os(iOS)
    private static let lightSurface = UIColor(red: 0.925, green: 0.929, blue: 0.98, alpha: 1)
    private static let lightElevated = UIColor(red: 0.949, green: 0.953, blue: 1.0, alpha: 1)
    #endif

    static var surface: Color {
        #if os(iOS)
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? .systemGroupedBackground : lightSurface
        })
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var cardLowest: Color {
        #if os(iOS)
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor.secondarySystemGroupedBackground
                : lightElevated
        })
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var cardInset: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .textBackgroundColor)
        #endif
    }

    static var link: Color {
        #if os(iOS)
        Color(UIColor.link)
        #else
        Color(nsColor: .linkColor)
        #endif
    }

    static var separator: Color {
        #if os(iOS)
        Color(UIColor.separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    static var responseShell: Color {
        Color(red: 0.11, green: 0.12, blue: 0.15)
    }

    static var responseFooter: Color {
        Color.black.opacity(0.22)
    }
}

private enum OpenAPIExecuteLayout {
    static let horizontalInset: CGFloat = 20
    static let cardInterior: CGFloat = 16
}

private enum OpenAPIExecuteScrollID: Hashable {
    case response
}

private func executionMethodBadgeBackground(_ method: String) -> Color {
    switch method.uppercased() {
    case "GET": return Color(red: 0.22, green: 0.52, blue: 0.95)
    case "POST": return Color(red: 0.12, green: 0.52, blue: 0.32)
    case "PUT", "PATCH": return Color(red: 0.98, green: 0.58, blue: 0.12)
    case "DELETE": return Color(red: 0.92, green: 0.26, blue: 0.28)
    default: return Color(white: 0.55)
    }
}

/// Builds URL, query, and body from the spec and sends HTTP for any method (not GET-only).
struct OpenAPIExecuteView: View {
    @State private var operationId: String = KawarimiSpec.endpoints.first?.operationId ?? ""
    @State private var searchText = ""
    @State private var pathParams: [String: String] = [:]
    @State private var queryString: String = ""
    @State private var bodyText: String = "{}"
    @State private var resultText: String = ""
    @State private var isRunning = false

    private var endpoints: [KawarimiSpec.Endpoint] { KawarimiSpec.endpoints }

    private var clientURL: URL? { KawarimiExampleConfig.clientBaseURL }

    private var filteredEndpoints: [KawarimiSpec.Endpoint] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return endpoints }
        let lower = q.lowercased()
        return endpoints.filter { ep in
            ep.path.lowercased().contains(lower)
                || ep.method.lowercased().contains(lower)
                || ep.operationId.lowercased().contains(lower)
        }
    }

    private var endpoint: KawarimiSpec.Endpoint? {
        endpoints.first { $0.operationId == operationId }
    }

    private var parsedHTTPStatus: (code: String, isError: Bool)? {
        let prefix = "HTTP "
        guard resultText.hasPrefix(prefix) else { return nil }
        let rest = String(resultText.dropFirst(prefix.count))
        guard let idx = rest.firstIndex(of: "\n") else { return nil }
        let code = String(rest[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let n = Int(code) ?? 0
        let err = n >= 400 || code == "?"
        return (code, err)
    }

    private var responseBodyOnly: String {
        guard !resultText.isEmpty else { return "" }
        if let idx = resultText.firstIndex(of: "\n") {
            return String(resultText[resultText.index(after: idx)...])
        }
        return resultText
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        pageIntro
                        baseURLCard
                        executeSearchField
                        operationPickerCard
                        methodAndPathCard
                        if let ep = endpoint {
                            pathParametersSection(ep: ep)
                            querySection
                            if HTTPRequestBodyPolicy.shouldShowJSONBodyEditor(method: ep.method) {
                                requestBodySection
                            }
                        }
                        if isRunning {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        if !resultText.isEmpty {
                            responseSection
                                .id(OpenAPIExecuteScrollID.response)
                        }
                    }
                    .padding(.horizontal, OpenAPIExecuteLayout.horizontalInset)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .onChange(of: resultText) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(50))
                        withAnimation(.easeInOut(duration: 0.28)) {
                            proxy.scrollTo(OpenAPIExecuteScrollID.response, anchor: .top)
                        }
                    }
                }
            }
            .background(ExecutionTheme.surface)
            .navigationTitle("API Execution")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .safeAreaInset(edge: .bottom, spacing: 0) {
                fixedRunBar
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 320)
#endif
        .onAppear {
            if operationId.isEmpty, let first = endpoints.first?.operationId {
                operationId = first
            }
            syncOperationInputs()
        }
        .onChange(of: searchText) { _, _ in
            let list = filteredEndpoints
            guard !list.isEmpty, !list.contains(where: { $0.operationId == operationId }) else { return }
            operationId = list[0].operationId
            syncOperationInputs()
        }
    }

    private var pageIntro: some View {
        Text("Design, test, and debug your endpoints with architectural precision.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var baseURLCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "network")
                    .font(.body.weight(.medium))
                    .foregroundStyle(ExecutionTheme.link)
                Text(clientURL?.absoluteString ?? "(invalid)")
                    .font(.body.monospaced())
                    .foregroundStyle(ExecutionTheme.link)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(OpenAPIExecuteLayout.cardInterior)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ExecutionTheme.cardLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ExecutionTheme.separator, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private var executeSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search endpoints, methods, or descriptions", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ExecutionTheme.cardLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ExecutionTheme.separator, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private var methodAndPathCard: some View {
        if let ep = endpoint {
            HStack(alignment: .center, spacing: 12) {
                Text(ep.method.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(executionMethodBadgeBackground(ep.method), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(ep.path)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(ExecutionTheme.link)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ExecutionTheme.cardInset)
                    )
            }
            .padding(OpenAPIExecuteLayout.cardInterior)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ExecutionTheme.cardLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ExecutionTheme.separator, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
    }

    private var operationPickerCard: some View {
        cardChrome(title: "Operation") {
            if filteredEndpoints.isEmpty, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No endpoints match your search.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Picker("Operation", selection: $operationId) {
                    ForEach(filteredEndpoints, id: \.operationId) { ep in
                        Text(ep.operationId).tag(ep.operationId)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Operation")
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ExecutionTheme.cardInset)
                )
                .onChange(of: operationId) { _, _ in
                    syncOperationInputs()
                }
            }
        }
    }

    @ViewBuilder
    private func pathParametersSection(ep: KawarimiSpec.Endpoint) -> some View {
        let names = bracedParamNames(in: ep.path)
        if !names.isEmpty {
            cardChrome(title: "Path parameters") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(names, id: \.self) { name in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            TextField(name, text: paramBinding(name))
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(ExecutionTheme.cardInset)
                                )
                        }
                    }
                }
            }
        }
    }

    private var querySection: some View {
        cardChrome(title: "Query string") {
            TextField("limit=20&offset=0", text: $queryString)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ExecutionTheme.cardInset)
                )
        }
    }

    private var requestBodySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Request body")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text("JSON payload to send.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            requestBodyEditorChrome
        }
    }

    private var requestBodyEditorChrome: some View {
        let lineCount = max(1, bodyText.split(separator: "\n", omittingEmptySubsequences: false).count)
        let minH = CGFloat(max(lineCount, 6)) * 18 + 20

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 8, height: 8)
                }
                Spacer(minLength: 0)
                Text("REQUEST-BODY")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.07, green: 0.075, blue: 0.09))

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(1...lineCount, id: \.self) { n in
                        Text("\(n)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .frame(height: 18, alignment: .top)
                    }
                }
                .frame(width: 32)
                .padding(.vertical, 8)

                TextEditor(text: $bodyText)
                    .font(.system(size: 13, design: .monospaced))
                    #if os(iOS)
                    .scrollContentBackground(.hidden)
                    #endif
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(minHeight: minH)
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
            }
            .background(Color(red: 0.1, green: 0.11, blue: 0.13))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var fixedRunBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(ExecutionTheme.separator)
                .frame(height: 1)
            runRequestButton
                .padding(.horizontal, OpenAPIExecuteLayout.horizontalInset)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .background(ExecutionTheme.surface)
    }

    private var runRequestButton: some View {
        Button {
            Task { await performRequest() }
        } label: {
            Label("Run Request", systemImage: "play.fill")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.22, green: 0.52, blue: 0.95))
        .disabled(clientURL == nil || isRunning || endpoint == nil)
        .shadow(color: Color(red: 0.22, green: 0.52, blue: 0.95).opacity(0.25), radius: 10, x: 0, y: 4)
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Response")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                if let s = parsedHTTPStatus {
                    Text(s.code)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(s.isError ? Color.red.opacity(0.85) : Color(red: 0.12, green: 0.52, blue: 0.32))
                        )
                }
            }
            .padding(.horizontal, OpenAPIExecuteLayout.cardInterior)
            .padding(.vertical, 12)
            .background(ExecutionTheme.responseShell)

            Text(responseBodyOnly.isEmpty ? resultText : responseBodyOnly)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
                .padding(OpenAPIExecuteLayout.cardInterior)
                .frame(minHeight: 120, alignment: .topLeading)
                .background(ExecutionTheme.responseShell)

            HStack {
                Text("UTF-8")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                Spacer(minLength: 0)
                Button {
                    copyResponseToPasteboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, OpenAPIExecuteLayout.cardInterior)
            .padding(.vertical, 10)
            .background(ExecutionTheme.responseFooter)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }

    private func cardChrome(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OpenAPIExecuteLayout.cardInterior)
                .padding(.vertical, 12)
                .background(ExecutionTheme.cardInset.opacity(0.65))

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(OpenAPIExecuteLayout.cardInterior)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ExecutionTheme.cardLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ExecutionTheme.separator, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private func copyResponseToPasteboard() {
        let text = responseBodyOnly.isEmpty ? resultText : responseBodyOnly
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
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

    @MainActor
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
            resultText = "HTTP 400\nError: path still contains `{…}` placeholders (fill path parameters)"
            return
        }

        guard var url = append(base: base, path: path) else {
            resultText = "HTTP 0\nError: failed to build URL"
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
            resultText = "HTTP 0\nError: \(error.localizedDescription)"
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
