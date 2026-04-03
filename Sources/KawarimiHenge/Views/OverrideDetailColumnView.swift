import KawarimiCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

struct OverrideDetailColumnView: View {
    let endpointItem: SpecEndpointItem
    let overrides: [MockOverride]
    let apiPathPrefix: String
    @Binding var mock: MockOverride
    @Binding var validationMessage: String?
    let hasUnsavedChanges: Bool
    let embedNavigationStack: Bool
    let showToolbarRefresh: Bool
    let onRefresh: () -> Void
    let onValidate: () -> Void
    let onFormat: () -> Void
    let onApply: () -> Void
    let onReset: () -> Void
    let onDisableCurrentMock: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var confirmResetEndpoint = false
    @State private var addCustomResponsePresented = false
    @State private var addCustomSelectedStatus: Int = 503
    @State private var addCustomFormError: String?
    @State private var addCustomScratchExampleId: String = ""

    private var addCustomStatusPickerCandidates: [Int] {
        ResponseChips.commonCustomHTTPStatusCodes
    }

    private var endpoint: any SpecEndpointProviding { endpointItem.endpoint }

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

    private func responseChipIsSelected(_ opt: ResponseChip) -> Bool {
        ResponseChips.chipIsSelected(
            option: opt,
            mock: mock,
            rowKey: endpointItem.rowKey,
            operationId: endpoint.operationId,
            pathPrefix: apiPathPrefix,
            overrides: overrides
        )
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
        mock.isEnabled
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

    private var mockEnabledBinding: Binding<Bool> {
        Binding(
            get: { mock.isEnabled },
            set: { newValue in
                var m = mock
                m.isEnabled = newValue
                mock = m
            }
        )
    }

    private var jsonLineCount: Int {
        let text = mock.body ?? ""
        if text.isEmpty { return 1 }
        return max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
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
        .frame(minWidth: 380, minHeight: 220)
        #endif
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

    private var detailScrollStack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: detailTightVertical ? 12 : 20) {
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

                VStack(alignment: .leading, spacing: detailTightVertical ? 6 : 8) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: detailTightVertical ? 4 : 6) {
                            Text("RESPONSE STATUS")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                            Text("Pick Spec to clear the mock, or a response row from the OpenAPI spec (each status / example is its own chip). Add creates another row for any HTTP status (new example id). Long-press a chip to copy its example id for X-Kawarimi-Example-Id. Del turns off an active mock; if it is already off, Del removes that row from the server config.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(detailTightVertical ? 4 : nil)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 10) {
                            Button {
                                presentAddCustomSheet()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add response row")

                            Button {
                                onDisableCurrentMock()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(canRemoveCurrentMockRow ? Color.orange : Color.secondary.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canRemoveCurrentMockRow)
                            .accessibilityLabel("Turn off mock, or delete row if already off")
                        }
                        .padding(.top, 2)
                    }
                    responseStatusChipStrip

                    Toggle(isOn: mockEnabledBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mock active")
                                .font(.subheadline.weight(.medium))
                            Text("Off: requests hit the real handler (same as Spec). On: the interceptor returns this row after Save.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.top, detailTightVertical ? 8 : 10)
                    .accessibilityLabel("Mock response active")
                }

                if shouldShowResponseBodySection {
                    VStack(alignment: .leading, spacing: detailTightVertical ? 8 : 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("RESPONSE BODY")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.6)
                                Text("JSON payload to be returned.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(detailTightVertical ? 2 : nil)
                            }
                            Spacer(minLength: 8)
                            HStack(spacing: 4) {
                                Image(systemName: "curlybraces")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(ExplorerPalette.linkAccent)
                                TextField("application/json", text: contentTypeBinding)
                                    .font(.caption.monospaced())
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: 140)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ExplorerPalette.subtleAccentFill)
                            )
                        }

                        darkJsonEditorChrome

                        if let msg = validationMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(EditorValidation.isInvalidJSONMessage(msg) ? .red : .secondary)
                        }
                    }
                }
            }
            .padding(detailTightVertical ? 10 : 16)
            .padding(.bottom, detailTightVertical ? 72 : 96)
        }
        .background(ExplorerPalette.surface)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomToolbar
        }
    }

    private var responseStatusChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chipOptions) { opt in
                    let selected = responseChipIsSelected(opt)
                    Button {
                        applyResponseChip(opt)
                    } label: {
                        HStack(spacing: 6) {
                            if selected, !opt.isSpec, mock.isEnabled {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                            Text(opt.label)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(
                                    selected
                                        ? (opt.isSpec ? Color.primary : Color.accentColor)
                                        : (opt.isInactive ? Color.secondary.opacity(0.75) : Color.secondary)
                                )
                        }
                        .padding(.horizontal, detailTightVertical ? 10 : 14)
                        .padding(.vertical, detailTightVertical ? 7 : 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? ExplorerPalette.chipSelectedFill : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            copyChipExampleIdToPasteboard(opt)
                        } label: {
                            Label("Copy example ID", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .padding(detailTightVertical ? 6 : 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ExplorerPalette.chipStripTray)
        )
    }

    private func copyChipExampleIdToPasteboard(_ opt: ResponseChip) {
        let text: String
        if opt.isSpec {
            text = KawarimiExampleIds.defaultResponseMapKey
        } else {
            text = KawarimiExampleIds.responseMapLookupKey(forOverrideExampleId: opt.exampleId)
        }
        #if canImport(UIKit) && !os(watchOS)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit) && !os(iOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private var darkJsonEditorChrome: some View {
        let lineCount = jsonLineCount
        let minLines = detailTightVertical ? 4 : 8
        let editorMinHeight = CGFloat(max(lineCount, minLines)) * 18 + (detailTightVertical ? 16 : 24)
        let editorFill = Color(red: 0.1, green: 0.11, blue: 0.13)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.green.opacity(0.85))
                        .frame(width: 8, height: 8)
                }
                Spacer(minLength: 0)
                Text("HENGE-EDITOR-V1")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, detailTightVertical ? 6 : 8)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.07, green: 0.075, blue: 0.09))

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(1...lineCount, id: \.self) { n in
                        Text("\(n)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(height: 18, alignment: .top)
                    }
                }
                .frame(width: 36)
                .padding(.vertical, detailTightVertical ? 6 : 8)

                TextEditor(text: bodyTextBinding)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(minHeight: editorMinHeight)
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
            }
            .background(editorFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var bottomToolbar: some View {
        HStack(spacing: 4) {
            toolbarPlainButton(title: "Validate", systemImage: "checkmark.circle", action: onValidate)
            toolbarPlainButton(title: "Format", systemImage: "text.alignleft", action: onFormat)
            saveCapsuleButton
            toolbarPlainButton(title: "Reset", systemImage: "arrow.counterclockwise", foreground: .red) {
                confirmResetEndpoint = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, detailTightVertical ? 8 : 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var saveCapsuleButton: some View {
        Button(action: onApply) {
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20))
                Text("Save")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, detailTightVertical ? 6 : 8)
            .padding(.horizontal, 6)
            .background(Capsule(style: .continuous).fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func toolbarPlainButton(
        title: String,
        systemImage: String,
        foreground: Color = Color.secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
    }
}
