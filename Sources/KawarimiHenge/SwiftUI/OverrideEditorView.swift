import KawarimiCore
import SwiftUI

private func validationMessageIsError(_ msg: String) -> Bool {
    msg.hasPrefix("Invalid")
}

struct OverrideEditorView: View {
    private let serverURL: String
    private let onRefresh: () -> Void
    private let onResetAll: () -> Void
    private let meta: (any SpecMetaProviding)?
    private let endpoints: [any SpecEndpointProviding]
    private let overrides: [MockOverride]
    private let isLoading: Bool
    private let specLoadID: Int
    private let overridesRevision: Int
    private let configureOverride: (MockOverride) async throws -> Void
    private let errorMessage: Binding<String?>

    @State private var store = OverrideEditorStore()
    @State private var confirmResetAll = false

    init(
        serverURL: String,
        onRefresh: @escaping () -> Void,
        onResetAll: @escaping () -> Void,
        meta: (any SpecMetaProviding)?,
        endpoints: [any SpecEndpointProviding],
        overrides: [MockOverride],
        isLoading: Bool,
        specLoadID: Int,
        overridesRevision: Int,
        configureOverride: @escaping (MockOverride) async throws -> Void,
        errorMessage: Binding<String?>
    ) {
        self.serverURL = serverURL
        self.onRefresh = onRefresh
        self.onResetAll = onResetAll
        self.meta = meta
        self.endpoints = endpoints
        self.overrides = overrides
        self.isLoading = isLoading
        self.specLoadID = specLoadID
        self.overridesRevision = overridesRevision
        self.configureOverride = configureOverride
        self.errorMessage = errorMessage
    }

    private var endpointItems: [SpecEndpointItem] {
        store.endpointItems(endpoints: endpoints)
    }

    var body: some View {
        NavigationSplitView {
            listContent
        } detail: {
            detailContent
        }
        .task(id: specLoadID) {
            store.resyncDetailAfterSpecReload(endpoints: endpoints, overrides: overrides)
        }
        .task(id: overridesRevision) {
            store.resyncDetailAfterOverridesRefresh(endpoints: endpoints, overrides: overrides)
        }
        .confirmationDialog(
            "Reset all overrides?",
            isPresented: $confirmResetAll,
            titleVisibility: .visible
        ) {
            Button("Reset All", role: .destructive) { onResetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All mock overrides on the server will be cleared. This cannot be undone here.")
        }
    }

    private var validationMessageBinding: Binding<String?> {
        Binding(
            get: { store.detail?.validationMessage },
            set: { newValue in
                guard var d = store.detail else { return }
                d.validationMessage = newValue
                store.commitDetail(d)
            }
        )
    }

    private var selectionBinding: Binding<EndpointRowKey?> {
        Binding(
            get: { store.selectedRowKey },
            set: { store.applySelection($0, endpoints: endpoints, overrides: overrides) }
        )
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(serverURL)
                    .font(.body.monospaced())
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Button("Refresh", action: onRefresh)
                    Button("Reset All", role: .destructive) { confirmResetAll = true }
                    Spacer(minLength: 0)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: selectionBinding) {
                    if let meta {
                        Section("API: \(meta.title) v\(meta.version)") {
                            ForEach(endpointItems) { item in
                                EndpointRowView(
                                    item: item,
                                    statusCode: store.displayedListStatus(for: item.rowKey, overrides: overrides),
                                    hasUnsavedDraft: store.detail?.isDirty == true && store.detail?.endpointRowKey == item.rowKey
                                )
                                .tag(item.rowKey)
                            }
                        }
                    } else {
                        Text("No spec loaded. Provide spec via specProvider.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let error = errorMessage.wrappedValue {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let d = store.detail,
           let item = store.specItem(for: d.endpointRowKey, endpoints: endpoints) {
            OverrideDetailColumnView(
                endpointItem: item,
                overrides: overrides,
                mock: mockBinding(for: item),
                validationMessage: validationMessageBinding,
                hasUnsavedChanges: d.isDirty,
                onValidate: { store.validateBody() },
                onFormat: { store.formatBody() },
                onApply: { Task { await applyWithBody(endpointItem: item) } },
                onReset: { Task { await clearOverride(endpointItem: item) } }
            )
        } else {
            Text("Select an endpoint")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func mockBinding(for item: SpecEndpointItem) -> Binding<MockOverride> {
        let endpoint = item.endpoint
        return Binding(
            get: {
                store.detail?.mock
                    ?? MockOverride(
                        name: endpoint.operationId,
                        path: endpoint.path,
                        method: endpoint.method,
                        statusCode: endpoint.responseList.first?.statusCode ?? 200,
                        isEnabled: false,
                        body: nil,
                        contentType: nil
                    )
            },
            set: { store.applyMockEdit(from: item, newMock: $0) }
        )
    }

    private func applyWithBody(endpointItem: SpecEndpointItem) async {
        let endpoint = endpointItem.endpoint
        errorMessage.wrappedValue = nil
        guard let draft = store.detail, draft.endpointRowKey == endpointItem.rowKey else { return }
        let m = draft.mock
        let enabled = m.isEnabled
        let trimmed = (m.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String?
        let contentType: String?
        if !enabled {
            body = nil
            contentType = nil
        } else {
            body = trimmed.isEmpty ? nil : m.body
            contentType = body == nil ? nil : ((m.contentType ?? "").isEmpty ? nil : m.contentType)
        }
        do {
            let override = MockOverride(
                name: endpoint.operationId,
                path: endpoint.path,
                method: endpoint.method,
                statusCode: enabled ? m.statusCode : (endpoint.responseList.first?.statusCode ?? 200),
                isEnabled: enabled,
                body: body,
                contentType: contentType
            )
            try await configureOverride(override)
            store.markSavedClean()
        } catch {
            errorMessage.wrappedValue = error.localizedDescription
        }
    }

    private func clearOverride(endpointItem: SpecEndpointItem) async {
        let endpoint = endpointItem.endpoint
        errorMessage.wrappedValue = nil
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
            store.applyServerReset(mock: override, rowKey: endpointItem.rowKey)
        } catch {
            errorMessage.wrappedValue = error.localizedDescription
        }
    }
}

private struct OverrideDetailColumnView: View {
    let endpointItem: SpecEndpointItem
    let overrides: [MockOverride]
    @Binding var mock: MockOverride
    @Binding var validationMessage: String?
    let hasUnsavedChanges: Bool
    let onValidate: () -> Void
    let onFormat: () -> Void
    let onApply: () -> Void
    let onReset: () -> Void

    @State private var confirmResetEndpoint = false

    private var endpoint: any SpecEndpointProviding { endpointItem.endpoint }

    private var responseSelectionBinding: Binding<Int> {
        Binding(
            get: { mock.isEnabled ? mock.statusCode : -1 },
            set: { newCode in
                var m = mock
                if newCode == -1 {
                    m.isEnabled = false
                    m.statusCode = endpoint.responseList.first?.statusCode ?? 200
                    m.body = nil
                    m.contentType = nil
                } else {
                    m.isEnabled = true
                    m.statusCode = newCode
                    mergeResponseTemplate(endpoint: endpoint, overrides: overrides, statusCode: newCode, into: &m)
                }
                mock = m
            }
        )
    }

    private var bodyTextBinding: Binding<String> {
        Binding(
            get: { mock.body ?? "" },
            set: { newValue in
                mock.body = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var contentTypeBinding: Binding<String> {
        Binding(
            get: { mock.contentType ?? "application/json" },
            set: { newValue in
                mock.contentType = newValue.isEmpty ? nil : newValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if hasUnsavedChanges {
                        HStack {
                            Text("Not saved")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.15), in: Capsule())
                            Spacer(minLength: 0)
                        }
                    }
                    Picker("Response", selection: responseSelectionBinding) {
                        Text("Spec").tag(-1)
                        ForEach(endpointItem.mockResponsePickerItems) { item in
                            Text("\(item.response.statusCode)").tag(item.response.statusCode)
                        }
                    }
                    .pickerStyle(.menu)

                    if mock.isEnabled {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                TextEditor(text: bodyTextBinding)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 120)
                                TextField("Content-Type", text: contentTypeBinding, prompt: Text("application/json"))
                                if let msg = validationMessage {
                                    Text(msg)
                                        .font(.caption)
                                        .foregroundStyle(validationMessageIsError(msg) ? .red : .secondary)
                                }
                                HStack(spacing: 8) {
                                    Button("Validate", action: onValidate)
                                    Button("Format", action: onFormat)
                                    Spacer(minLength: 0)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        } label: {
                            Label("Response body (JSON)", systemImage: "curlybraces")
                                .font(.subheadline)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Save", action: onApply)
                            .buttonStyle(.borderedProminent)
                        Button("Reset", role: .destructive) { confirmResetEndpoint = true }
                            .buttonStyle(.bordered)
                        Spacer(minLength: 0)
                    }
                    .controlSize(.regular)
                }
                .padding()
            }
            .navigationTitle("\(endpoint.method) \(endpoint.path)")
            .confirmationDialog(
                "Reset this endpoint?",
                isPresented: $confirmResetEndpoint,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { onReset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The override for this operation will be cleared on the server.")
            }
        }
    }
}

private struct EndpointRowView: View {
    let item: SpecEndpointItem
    let statusCode: Int
    let hasUnsavedDraft: Bool

    private var endpoint: any SpecEndpointProviding { item.endpoint }

    var body: some View {
        HStack {
            Text(endpoint.method)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(endpoint.path)
                .font(.system(.body, design: .monospaced))
            if hasUnsavedDraft {
                Text("Unsaved")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Spacer()
            Text(statusCode == -1 ? "Spec" : "\(statusCode)")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(statusCode == -1 ? .secondary : .primary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}
