import KawarimiCore
import KawarimiHengeCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

struct DetailColumnHeaderView: View {
    let model: DetailColumnHeaderModel
    let actions: DetailColumnHeaderActions
    let bindings: DetailColumnHeaderBindings

    private var endpoint: any SpecEndpointProviding { model.endpointItem.endpoint }

    var body: some View {
        VStack(alignment: .leading, spacing: model.tightVertical ? 12 : 20) {
            operationIdSection
            rowIdSection
            tagsDocumentationSection
            parametersDocumentationSection
            securityDocumentationSection
            detailTopChrome
            if model.showResponseBodyHeading {
                responseBodyHeading
            }
        }
        .padding(model.tightVertical ? 10 : 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var operationIdSection: some View {
        VStack(alignment: .leading, spacing: model.tightVertical ? 6 : 8) {
            Text("OPERATION ID")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text(endpoint.operationId)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(model.tightVertical ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ExplorerPalette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private var rowIdSection: some View {
        if let rowId = model.persistedRowId {
            VStack(alignment: .leading, spacing: model.tightVertical ? 6 : 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("ROW ID")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    Spacer()
                    Button {
                        copyRowIdToPasteboard(rowId)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                Text(rowId)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            .padding(model.tightVertical ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ExplorerPalette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
    }

    @ViewBuilder
    private var tagsDocumentationSection: some View {
        if let tags = TagsPresentation.displayTags(for: endpoint) {
            VStack(alignment: .leading, spacing: model.tightVertical ? 8 : 10) {
                Text("TAGS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(ExplorerPalette.subtleAccentFill)
                                )
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(model.tightVertical ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ExplorerPalette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
    }

    @ViewBuilder
    private var parametersDocumentationSection: some View {
        if let lines = ParametersPresentation.displayLines(for: endpoint) {
            VStack(alignment: .leading, spacing: model.tightVertical ? 8 : 10) {
                Text("PARAMETERS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(model.tightVertical ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ExplorerPalette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
    }

    @ViewBuilder
    private var securityDocumentationSection: some View {
        if model.securityPresentation.hasContent {
            VStack(alignment: .leading, spacing: model.tightVertical ? 8 : 10) {
                Text("SECURITY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                if model.securityPresentation.requirementLines.isEmpty {
                    Text("No security requirement for this operation.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if model.securityPresentation.requirementLines.count == 1 {
                    Text(model.securityPresentation.requirementLines[0])
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                } else {
                    Text("Satisfy one of:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(model.securityPresentation.requirementLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                }
                if !model.securityPresentation.schemeDetails.isEmpty {
                    DisclosureGroup("Scheme definitions") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(model.securityPresentation.schemeDetails) { detail in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(detail.name)
                                        .font(.caption.weight(.semibold))
                                    Text(detail.summary)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    if let description = detail.description, !description.isEmpty {
                                        Text(description)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .font(.caption.weight(.medium))
                }
            }
            .padding(model.tightVertical ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ExplorerPalette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
    }

    @ViewBuilder
    private var detailTopChrome: some View {
        if model.hasUnsavedChanges {
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

        VStack(alignment: .leading, spacing: model.tightVertical ? 6 : 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: model.tightVertical ? 4 : 6) {
                    Text("RESPONSE STATUS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    Text("P marks the row that is active on the server (primary mock). Selected chip is what you are editing. When no row is active, Spec is effective. Save sends the current chip: enabled rows become primary; disabled rows stay off and still persist JSON. Add creates another row. Long-press a chip to copy example id. Del removes the saved row for the current chip from the server, or clears an unsaved draft locally.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(model.tightVertical ? 4 : nil)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button(action: actions.onPresentAddCustom) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add response row")

                    Button(action: actions.onDisableCurrentMock) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(model.canRemoveCurrentMockRow ? Color.orange : Color.secondary.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canRemoveCurrentMockRow)
                    .accessibilityLabel("Remove saved row, or clear unsaved draft")

                    Button(action: actions.onRemoveDisabledOverrides) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(model.disabledOverridesCount > 0 ? Color.orange : Color.secondary.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.disabledOverridesCount == 0)
                    .accessibilityLabel("Remove all disabled rows for this operation")
                }
                .padding(.top, 2)
            }
            responseStatusChipStrip
        }

        selectedResponseDocumentationSection

        VStack(alignment: .leading, spacing: model.tightVertical ? 6 : 8) {
            Text("RESPONSE DELAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text("Optional delay in milliseconds before the mock response is returned. Leave empty for no delay.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(model.tightVertical ? 2 : nil)
            TextField("ms", text: bindings.delayMsText)
                .font(.body.monospacedDigit())
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .frame(maxWidth: 120)
        }

        VStack(alignment: .leading, spacing: model.tightVertical ? 6 : 8) {
            Text("FAILURE PROFILE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text("Optional failure simulation. Hang never returns a response and overrides delay. Connection close aborts before a mock response.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(model.tightVertical ? 3 : nil)
            Picker("Failure profile", selection: failureModeSelection) {
                Text("None").tag("")
                Text("Hang").tag(MockFailureMode.hang.rawValue)
                Text("Connection close").tag(MockFailureMode.connectionClose.rawValue)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 240, alignment: .leading)
        }
    }

    private var failureModeSelection: Binding<String> {
        Binding(
            get: { bindings.mock.wrappedValue.failureMode?.rawValue ?? "" },
            set: { raw in
                bindings.mock.wrappedValue.failureMode = raw.isEmpty ? nil : MockFailureMode(rawValue: raw)
            }
        )
    }

    @ViewBuilder
    private var selectedResponseDocumentationSection: some View {
        if let doc = model.selectedResponseDocumentation {
            VStack(alignment: .leading, spacing: model.tightVertical ? 6 : 8) {
                Text("SELECTED RESPONSE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                if let summary = doc.summary {
                    Text(summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let description = doc.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .padding(model.tightVertical ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ExplorerPalette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
    }

    @ViewBuilder
    private var responseBodyHeading: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RESPONSE BODY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Text("JSON payload to be returned.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(model.tightVertical ? 2 : nil)
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Image(systemName: "curlybraces")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ExplorerPalette.linkAccent)
                TextField("application/json", text: bindings.contentTypeText)
                    .font(.caption.monospaced())
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 140)
                    .focused(bindings.focus, equals: .contentType)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(ExplorerPalette.subtleAccentFill)
            )
        }
    }

    private var responseStatusChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.chipOptions) { opt in
                    let selected = responseChipIsSelected(opt)
                    let primaryHere = chipMatchesServerPrimary(opt)
                    let specEffective = opt.isSpec && specChipIsServerEffective
                    Button {
                        actions.onApplyChip(opt)
                    } label: {
                        HStack(spacing: 6) {
                            if primaryHere {
                                Text("P")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.green)
                                    .accessibilityLabel("Primary on server")
                            }
                            Text(opt.label)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(
                                    selected
                                        ? ExplorerPalette.chipSelectedLabel
                                        : (opt.isInactive ? Color.secondary.opacity(0.75) : Color.secondary)
                                )
                        }
                        .padding(.horizontal, model.tightVertical ? 10 : 14)
                        .padding(.vertical, model.tightVertical ? 7 : 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? ExplorerPalette.chipSelectedFill : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    specEffective ? Color.accentColor.opacity(0.85) : ExplorerPalette.groupedFieldStroke,
                                    lineWidth: specEffective ? 2 : 1
                                )
                                .allowsHitTesting(false)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(primaryHere ? "Primary mock on server" : "")
                    .contextMenu {
                        Button {
                            copyChipExampleIdToPasteboard(opt)
                        } label: {
                            Label("Copy example ID", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .padding(model.tightVertical ? 6 : 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ExplorerPalette.chipStripTray)
        )
    }

    private func responseChipIsSelected(_ opt: ResponseChip) -> Bool {
        ResponseChips.chipIsSelected(
            option: opt,
            mock: bindings.mock.wrappedValue,
            endpoint: endpoint,
            pinnedNumberedResponseChip: model.pinnedNumberedResponseChip
        )
    }

    private func chipMatchesServerPrimary(_ opt: ResponseChip) -> Bool {
        guard !opt.isSpec, let p = model.primaryOverride else { return false }
        guard opt.statusCode == p.statusCode,
              MockExamplePresentation.exampleIdsEqual(opt.exampleId, p.exampleId) else { return false }

        if let chipIdx = opt.specResponseListIndex,
           let wantIdx = OverrideListQueries.specResponseListIndexForPrimaryBadge(primary: p, endpoint: endpoint) {
            return chipIdx == wantIdx
        }
        return true
    }

    private var specChipIsServerEffective: Bool {
        model.primaryOverride == nil
    }

    private func copyRowIdToPasteboard(_ rowId: String) {
        #if canImport(UIKit) && !os(watchOS)
        UIPasteboard.general.string = rowId
        #elseif canImport(AppKit) && !os(iOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rowId, forType: .string)
        #endif
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
}
