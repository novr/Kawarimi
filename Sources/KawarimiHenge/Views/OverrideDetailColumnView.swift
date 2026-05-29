import KawarimiCore
import KawarimiHengeCore
import SwiftUI

struct OverrideDetailColumnView: View {
    let endpointItem: SpecEndpointItem
    let securitySchemeCatalog: [any SpecSecuritySchemeProviding]?
    let overrides: [MockOverride]
    let apiPathPrefix: String
    /// Server-side primary enabled row for this operation (`nil` = effective Spec).
    let primaryOverride: MockOverride?
    @Binding var mock: MockOverride
    @Binding var validationMessage: String?
    let hasUnsavedChanges: Bool
    let embedNavigationStack: Bool
    let showToolbarRefresh: Bool
    let onRefresh: () -> Void
    let onValidate: () -> Void
    let onFormat: () -> Void
    let onSave: () -> Void
    let onReset: () -> Void
    let onDisableCurrentMock: () -> Void
    let pinnedNumberedResponseChip: Bool
    let onResponseChipSelected: (ResponseChip) -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var confirmResetEndpoint = false
    @State private var addCustomResponsePresented = false
    @State private var addCustomSelectedStatus: Int = 503
    @State private var addCustomFormError: String?
    @State private var addCustomScratchExampleId: String = ""
    @FocusState private var detailFocus: DetailColumnFocusField?

    private var addCustomStatusPickerCandidates: [Int] {
        ResponseChips.commonCustomHTTPStatusCodes
    }

    private var endpoint: any SpecEndpointProviding { endpointItem.endpoint }

    private var securityPresentation: EndpointSecurityPresentation {
        SecurityPresentation.endpointPresentation(
            endpoint: endpoint,
            catalog: securitySchemeCatalog
        )
    }

    private var selectedResponseDocumentation: ResponseDocumentation? {
        ResponsePresentation.documentationForSelection(
            options: chipOptions,
            mock: mock,
            endpoint: endpoint,
            pinnedNumberedResponseChip: pinnedNumberedResponseChip
        )
    }

    private var detailTightVertical: Bool {
        #if os(iOS)
        verticalSizeClass == .compact
        #else
        false
        #endif
    }

    private var chipOptions: [ResponseChip] {
        ResponseChips.buildChipOptions(
            mock: mock,
            endpointItem: endpointItem,
            endpoint: endpoint,
            overrides: overrides,
            pathPrefix: apiPathPrefix
        )
    }

    private func responseOptionExists(statusCode: Int, exampleId: String?) -> Bool {
        ResponseChips.responseOptionExists(statusCode: statusCode, exampleId: exampleId, options: chipOptions)
    }

    private func applyResponseChip(_ opt: ResponseChip) {
        var m = mock
        ResponseChips.applyChipSelection(
            option: opt,
            mock: &m,
            endpointItem: endpointItem,
            endpoint: endpoint,
            overrides: overrides,
            pathPrefix: apiPathPrefix
        )
        mock = m
        onResponseChipSelected(opt)
    }

    private var shouldShowResponseBodySection: Bool {
        if mock.isEnabled { return true }
        return OverrideListQueries.hasStoredRowMatchingDraft(
            mock,
            rowKey: endpointItem.rowKey,
            operationId: endpoint.operationId,
            pathPrefix: apiPathPrefix,
            in: overrides
        )
    }

    private var canRemoveCurrentMockRow: Bool {
        hasUnsavedChanges
            || OverrideListQueries.hasStoredRowMatchingDraft(
                mock,
                rowKey: endpointItem.rowKey,
                operationId: endpoint.operationId,
                pathPrefix: apiPathPrefix,
                in: overrides
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

    private var delayMsBinding: Binding<String> {
        Binding(
            get: { mock.delayMs.map(String.init) ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    mock.delayMs = nil
                } else if let ms = Int(trimmed), ms >= 0 {
                    mock.delayMs = ms
                }
            }
        )
    }

    var body: some View {
        Group {
            if embedNavigationStack {
                NavigationStack {
                    detailScrollStack
                        .navigationTitle("\(endpoint.method.rawValue) \(endpoint.path)")
                        .toolbar {
                            if showToolbarRefresh {
                                ToolbarItem(placement: .kawarimiTrailing) {
                                    Button("Refresh", action: onRefresh)
                                }
                            }
                        }
                }
            } else {
                detailScrollStack
            }
        }
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
        .sheet(isPresented: $addCustomResponsePresented) {
            addCustomResponseSheet
        }
    }

    private var detailColumnHeaderModel: DetailColumnHeaderModel {
        DetailColumnHeaderModel(
            endpointItem: endpointItem,
            securityPresentation: securityPresentation,
            chipOptions: chipOptions,
            primaryOverride: primaryOverride,
            pinnedNumberedResponseChip: pinnedNumberedResponseChip,
            hasUnsavedChanges: hasUnsavedChanges,
            tightVertical: detailTightVertical,
            showResponseBodyHeading: shouldShowResponseBodySection,
            selectedResponseDocumentation: selectedResponseDocumentation,
            canRemoveCurrentMockRow: canRemoveCurrentMockRow
        )
    }

    private var detailColumnHeaderActions: DetailColumnHeaderActions {
        DetailColumnHeaderActions(
            onApplyChip: applyResponseChip,
            onDisableCurrentMock: onDisableCurrentMock,
            onPresentAddCustom: presentAddCustomSheet
        )
    }

    private var detailColumnHeaderBindings: DetailColumnHeaderBindings {
        DetailColumnHeaderBindings(
            mock: $mock,
            contentTypeText: contentTypeBinding,
            delayMsText: delayMsBinding,
            focus: $detailFocus
        )
    }

    private var detailScrollStack: some View {
        DetailColumnScrollStack(
            showResponseBody: shouldShowResponseBodySection,
            header: {
                DetailColumnHeaderView(
                    model: detailColumnHeaderModel,
                    actions: detailColumnHeaderActions,
                    bindings: detailColumnHeaderBindings
                )
            },
            editor: {
                DetailColumnJsonEditorView(
                    bodyText: bodyTextBinding,
                    validationMessage: validationMessage,
                    tightVertical: detailTightVertical,
                    focus: $detailFocus
                )
            },
            toolbar: {
                DetailColumnBottomToolbarView(
                    tightVertical: detailTightVertical,
                    onValidate: onValidate,
                    onFormat: onFormat,
                    onSave: onSave,
                    confirmResetEndpoint: $confirmResetEndpoint
                )
            }
        )
    }

    private func presentAddCustomSheet() {
        addCustomFormError = nil
        addCustomScratchExampleId = String(Self.autoGeneratedSupplementalExampleId())
        let candidates = addCustomStatusPickerCandidates
        if let first = candidates.first {
            addCustomSelectedStatus = candidates.contains(addCustomSelectedStatus) ? addCustomSelectedStatus : first
        }
        addCustomResponsePresented = true
    }

    private var addCustomResponseSheet: some View {
        let candidates = addCustomStatusPickerCandidates
        return NavigationStack {
            Group {
                #if os(macOS)
                addCustomResponseSheetMacOS(candidates: candidates)
                #else
                addCustomResponseSheetIOSForm(candidates: candidates)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ExplorerPalette.surface)
            .navigationTitle("Add response")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .presentationBackground(ExplorerPalette.surface)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        addCustomResponsePresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        submitAddCustomResponse()
                    }
                    .disabled(candidates.isEmpty)
                }
            }
            .onAppear {
                if addCustomScratchExampleId.isEmpty {
                    addCustomScratchExampleId = String(Self.autoGeneratedSupplementalExampleId())
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440)
        #endif
    }

    @ViewBuilder
    private func addCustomResponseSheetMacOS(candidates: [Int]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("HTTP status")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                if candidates.isEmpty {
                    Text("Every common HTTP status for this sheet already appears in the OpenAPI spec for this operation. Use the chips above instead.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.subheadline.weight(.medium))
                        Picker("Status", selection: $addCustomSelectedStatus) {
                            ForEach(candidates, id: \.self) { code in
                                Text("\(code) \(HTTPStatusPhrase.text(for: code))")
                                    .tag(code)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityLabel("Status")
                    }
                }
                Text("A new example id is assigned automatically. The body is filled from the spec when possible—edit it on the main screen. Save there to apply to the server. Clients can use X-Kawarimi-Example-Id to pick among enabled mocks.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if let addCustomFormError {
                    Text(addCustomFormError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func addCustomResponseSheetIOSForm(candidates: [Int]) -> some View {
        Form {
            Section {
                if candidates.isEmpty {
                    Text("Every common HTTP status for this sheet already appears in the OpenAPI spec for this operation. Use the chips above instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Status", selection: $addCustomSelectedStatus) {
                        ForEach(candidates, id: \.self) { code in
                            Text("\(code) \(HTTPStatusPhrase.text(for: code))")
                                .tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("HTTP status")
            } footer: {
                Text("A new example id is assigned automatically. The body is filled from the spec when possible—edit it on the main screen. Save there to apply to the server. Clients can use X-Kawarimi-Example-Id to pick among enabled mocks.")
            }
            if let addCustomFormError {
                Section {
                    Text(addCustomFormError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private static func autoGeneratedSupplementalExampleId() -> String {
        UUID().uuidString.prefix(8).lowercased()
    }

    private func submitAddCustomResponse() {
        addCustomFormError = nil
        let candidates = addCustomStatusPickerCandidates
        guard !candidates.isEmpty else { return }
        let code = addCustomSelectedStatus
        guard candidates.contains(code) else {
            addCustomFormError = "Pick a status from the list."
            return
        }
        let ex = addCustomScratchExampleId.isEmpty ? String(Self.autoGeneratedSupplementalExampleId()) : addCustomScratchExampleId
        if responseOptionExists(statusCode: code, exampleId: ex) {
            addCustomFormError = "This combination is already in the list. Try Add again for a new example id."
            return
        }
        var m = mock
        m.isEnabled = true
        m.statusCode = code
        m.exampleId = ex
        mergeResponseTemplate(
            endpoint: endpoint,
            overrides: overrides,
            pathPrefix: apiPathPrefix,
            statusCode: code,
            into: &m
        )
        mock = m
        addCustomResponsePresented = false
    }
}
