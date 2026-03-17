import KawarimiCore
import SwiftUI

/// SwiftUI view for editing mock overrides (status and optional custom body/contentType).
/// Uses protocol-returning closures so the app hides its implementation (e.g. KawarimiSpec, API client).
public struct OverrideEditorView: View {
    private let specProvider: () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding])
    private let fetchOverrides: () async throws -> [MockOverride]
    private let configureOverride: (MockOverride) async throws -> Void
    private let resetAllOverrides: () async throws -> Void

    @State private var meta: (any SpecMetaProviding)?
    @State private var endpoints: [any SpecEndpointProviding] = []
    @State private var selectedCodes: [String: Int] = [:]
    @State private var selectedEndpointKey: String?
    @State private var customBodyText: String = ""
    @State private var customContentType: String = "application/json"
    @State private var useCustomBody: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var validationMessage: String?
    /// True when detail panel has edits not yet applied. Used to confirm before switching selection.
    @State private var detailDirty = false
    @State private var showDiscardConfirmation = false
    @State private var pendingSelectionKey: String?

    public init(
        specProvider: @escaping () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding]),
        fetchOverrides: @escaping () async throws -> [MockOverride],
        configureOverride: @escaping (MockOverride) async throws -> Void,
        resetAllOverrides: @escaping () async throws -> Void
    ) {
        self.specProvider = specProvider
        self.fetchOverrides = fetchOverrides
        self.configureOverride = configureOverride
        self.resetAllOverrides = resetAllOverrides
    }

    public var body: some View {
        NavigationSplitView {
            listContent
        } detail: {
            detailContent
        }
        .task { await refresh() }
        .onChange(of: selectedEndpointKey) { _, newKey in
            guard let key = newKey,
                  let index = endpoints.firstIndex(where: { rowKey($0) == key }) else { return }
            let endpoint = endpoints[index]
            let code = selectedCodes[key] ?? 200
            if let resp = endpoint.responseList.first(where: { $0.statusCode == code }) {
                customBodyText = resp.body
                customContentType = resp.contentType
            }
            detailDirty = false
        }
        .onChange(of: selectedCodes) { _, _ in
            if let key = selectedEndpointKey,
               let index = endpoints.firstIndex(where: { rowKey($0) == key }) {
                let endpoint = endpoints[index]
                let code = selectedCodes[key] ?? 200
                if let resp = endpoint.responseList.first(where: { $0.statusCode == code }) {
                    customBodyText = resp.body
                    customContentType = resp.contentType
                }
            }
        }
        .onChange(of: customBodyText) { _, _ in detailDirty = true }
        .onChange(of: customContentType) { _, _ in detailDirty = true }
        .onChange(of: useCustomBody) { _, _ in detailDirty = true }
        .confirmationDialog("Discard unapplied changes?", isPresented: $showDiscardConfirmation) {
            Button("Discard", role: .destructive) {
                if let key = pendingSelectionKey {
                    selectedEndpointKey = key
                    pendingSelectionKey = nil
                    detailDirty = false
                    if let index = endpoints.firstIndex(where: { rowKey($0) == key }) {
                        let endpoint = endpoints[index]
                        let code = selectedCodes[key] ?? 200
                        if let resp = endpoint.responseList.first(where: { $0.statusCode == code }) {
                            customBodyText = resp.body
                            customContentType = resp.contentType
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSelectionKey = nil
            }
        } message: {
            Text("The detail has unapplied changes. Discard and switch endpoint?")
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: selectionBinding) {
                    if let meta {
                        Section("API: \(meta.title) v\(meta.version)") {
                            ForEach(endpointKeys, id: \.self) { key in
                                if let index = endpoints.firstIndex(where: { rowKey($0) == key }) {
                                    let endpoint = endpoints[index]
                                    EndpointRowView(
                                        endpoint: endpoint,
                                        selectedCode: Binding(
                                            get: { selectedCodes[key] ?? -1 },
                                            set: { newValue in
                                                selectedCodes[key] = newValue
                                                Task { await applyOverride(endpoint: endpoint, statusCode: newValue) }
                                            }
                                        )
                                    )
                                    .tag(key)
                                }
                            }
                        }
                    } else {
                        Text("No spec loaded. Provide spec via specProvider.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let key = selectedEndpointKey,
           let index = endpoints.firstIndex(where: { rowKey($0) == key }) {
            let endpoint = endpoints[index]
            DetailPanelView(
                endpoint: endpoint,
                selectedStatusCode: selectedCodes[key] ?? -1,
                customBodyText: $customBodyText,
                customContentType: $customContentType,
                useCustomBody: $useCustomBody,
                validationMessage: $validationMessage,
                onStatusCodeChange: { newCode in
                    selectedCodes[key] = newCode
                    Task { await applyOverride(endpoint: endpoint, statusCode: newCode) }
                },
                onSpecValuesReflect: { applySpecValuesToEditor(endpoint: endpoint) },
                onValidate: validateBody,
                onFormat: formatBody,
                onApply: { Task { await applyWithBody(endpoint: endpoint) } },
                onRevertToSpec: { Task { await revertToSpec(endpoint: endpoint) } }
            )
        } else {
            Text("Select an endpoint")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Stable id for list rows (method:path). Used for ForEach id and selection.
    private var endpointKeys: [String] {
        endpoints.map { rowKey($0) }
    }

    /// Intercepts selection change: if detail has unapplied changes, shows confirmation before switching.
    private var selectionBinding: Binding<String?> {
        Binding(
            get: { selectedEndpointKey },
            set: { newValue in
                guard newValue != selectedEndpointKey else { return }
                if detailDirty {
                    pendingSelectionKey = newValue
                    showDiscardConfirmation = true
                    return
                }
                selectedEndpointKey = newValue
            }
        )
    }

    private func rowKey(_ endpoint: any SpecEndpointProviding) -> String {
        "\(endpoint.method):\(endpoint.path)"
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let specResult = try await specProvider()
            let overrides = try await fetchOverrides()
            meta = specResult.meta
            endpoints = specResult.endpoints
            var codes: [String: Int] = [:]
            for endpoint in specResult.endpoints {
                codes[rowKey(endpoint)] = -1
            }
            for ov in overrides where ov.isEnabled {
                codes["\(ov.method):\(ov.path)"] = ov.statusCode
            }
            selectedCodes = codes
            detailDirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func applyOverride(endpoint: any SpecEndpointProviding, statusCode: Int) async {
        errorMessage = nil
        do {
            let override = MockOverride(
                name: endpoint.operationId,
                path: endpoint.path,
                method: endpoint.method,
                statusCode: statusCode == -1 ? (endpoint.responseList.first?.statusCode ?? 200) : statusCode,
                isEnabled: statusCode != -1,
                body: nil,
                contentType: nil
            )
            try await configureOverride(override)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applySpecValuesToEditor(endpoint: any SpecEndpointProviding) {
        let code = selectedCodes[rowKey(endpoint)] ?? 200
        guard let resp = endpoint.responseList.first(where: { $0.statusCode == code }) else {
            customBodyText = ""
            customContentType = "application/json"
            return
        }
        customBodyText = resp.body
        customContentType = resp.contentType
    }

    private func validateBody() {
        let data = Data(customBodyText.utf8)
        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            validationMessage = "Valid JSON"
        } else {
            validationMessage = "Invalid JSON"
        }
    }

    private func formatBody() {
        guard let data = customBodyText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8) else {
            validationMessage = "Invalid JSON (cannot format)"
            return
        }
        customBodyText = str
        validationMessage = "Formatted"
    }

    private func applyWithBody(endpoint: any SpecEndpointProviding) async {
        errorMessage = nil
        let code = selectedCodes[rowKey(endpoint)] ?? 200
        do {
            let override = MockOverride(
                name: endpoint.operationId,
                path: endpoint.path,
                method: endpoint.method,
                statusCode: code,
                isEnabled: true,
                body: useCustomBody ? customBodyText : nil,
                contentType: useCustomBody ? (customContentType.isEmpty ? nil : customContentType) : nil
            )
            try await configureOverride(override)
            detailDirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revertToSpec(endpoint: any SpecEndpointProviding) async {
        errorMessage = nil
        do {
            let override = MockOverride(
                name: endpoint.operationId,
                path: endpoint.path,
                method: endpoint.method,
                statusCode: endpoint.responseList.first?.statusCode ?? 200,
                isEnabled: false,
                body: nil,
                contentType: nil
            )
            try await configureOverride(override)
            selectedCodes[rowKey(endpoint)] = -1
            useCustomBody = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Endpoint row (protocol-based)

private struct EndpointRowView: View {
    let endpoint: any SpecEndpointProviding
    @Binding var selectedCode: Int

    var body: some View {
        HStack {
            Text(endpoint.method)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(endpoint.path)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Picker("Status", selection: $selectedCode) {
                Text("Disabled").tag(-1)
                ForEach(endpoint.responseList.indices, id: \.self) { i in
                    let r = endpoint.responseList[i]
                    Text("\(r.statusCode)").tag(r.statusCode)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail panel (body/contentType edit)

private struct DetailPanelView: View {
    let endpoint: any SpecEndpointProviding
    let selectedStatusCode: Int
    @Binding var customBodyText: String
    @Binding var customContentType: String
    @Binding var useCustomBody: Bool
    @Binding var validationMessage: String?
    let onStatusCodeChange: (Int) -> Void
    let onSpecValuesReflect: () -> Void
    let onValidate: () -> Void
    let onFormat: () -> Void
    let onApply: () -> Void
    let onRevertToSpec: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(endpoint.method) \(endpoint.path)")
                    .font(.headline)
                Picker("Status", selection: Binding(
                    get: { selectedStatusCode },
                    set: { onStatusCodeChange($0) }
                )) {
                    Text("Disabled").tag(-1)
                    ForEach(endpoint.responseList.indices, id: \.self) { i in
                        Text("\(endpoint.responseList[i].statusCode)").tag(endpoint.responseList[i].statusCode)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Use custom body", isOn: $useCustomBody)
                if useCustomBody {
                    TextEditor(text: $customBodyText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                    TextField("Content-Type", text: $customContentType, prompt: Text("application/json"))
                    if let msg = validationMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(msg.hasPrefix("Invalid") ? .red : .secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button("Spec の値を反映", action: onSpecValuesReflect)
                    Button("Validate", action: onValidate)
                    Button("Format", action: onFormat)
                    Button("Apply", action: onApply)
                    Button("Spec に戻す", role: .destructive, action: onRevertToSpec)
                }
            }
            .padding()
        }
    }
}
