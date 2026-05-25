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
    let endpointItem: SpecEndpointItem
    let securityPresentation: EndpointSecurityPresentation
    let chipOptions: [ResponseChip]
    let primaryOverride: MockOverride?
    @Binding var mock: MockOverride
    let pinnedNumberedResponseChip: Bool
    let hasUnsavedChanges: Bool
    let tightVertical: Bool
    let showResponseBodyHeading: Bool
    let selectedResponseDocumentation: ResponseDocumentation?
    let canRemoveCurrentMockRow: Bool
    let onApplyChip: (ResponseChip) -> Void
    let onDisableCurrentMock: () -> Void
    let onPresentAddCustom: () -> Void
    @Binding var contentTypeText: String
    @Binding var delayMsText: String
    var focus: FocusState<DetailColumnFocusField?>.Binding

    private var endpoint: any SpecEndpointProviding { endpointItem.endpoint }

    var body: some View {
        VStack(alignment: .leading, spacing: tightVertical ? 12 : 20) {
            operationIdSection
            tagsDocumentationSection
            securityDocumentationSection
            detailTopChrome
            if showResponseBodyHeading {
                responseBodyHeading
            }
        }
        .padding(tightVertical ? 10 : 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var operationIdSection: some View {
        VStack(alignment: .leading, spacing: tightVertical ? 6 : 8) {
            Text("OPERATION ID")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text(endpoint.operationId)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(tightVertical ? 10 : 12)
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
    private var tagsDocumentationSection: some View {
        if let tags = TagsPresentation.displayTags(for: endpoint) {
            VStack(alignment: .leading, spacing: tightVertical ? 8 : 10) {
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
            .padding(tightVertical ? 10 : 12)
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
        if securityPresentation.hasContent {
            VStack(alignment: .leading, spacing: tightVertical ? 8 : 10) {
                Text("SECURITY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                if securityPresentation.requirementLines.isEmpty {
                    Text("No security requirement for this operation.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if securityPresentation.requirementLines.count == 1 {
                    Text(securityPresentation.requirementLines[0])
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                } else {
                    Text("Satisfy one of:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(securityPresentation.requirementLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                }
                if !securityPresentation.schemeDetails.isEmpty {
                    DisclosureGroup("Scheme definitions") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(securityPresentation.schemeDetails) { detail in
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
            .padding(tightVertical ? 10 : 12)
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

        VStack(alignment: .leading, spacing: tightVertical ? 6 : 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: tightVertical ? 4 : 6) {
                    Text("RESPONSE STATUS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    Text("P marks the row that is active on the server (primary mock). Selected chip is what you are editing. When no row is active, Spec is effective. Save sends the current chip: enabled rows become primary; disabled rows stay off and still persist JSON. Add creates another row. Long-press a chip to copy example id. Del turns off an active mock or removes an inactive row.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(tightVertical ? 4 : nil)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button(action: onPresentAddCustom) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add response row")

                    Button(action: onDisableCurrentMock) {
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
        }

        selectedResponseDocumentationSection

        VStack(alignment: .leading, spacing: tightVertical ? 6 : 8) {
            Text("RESPONSE DELAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text("Optional delay in milliseconds before the mock response is returned. Leave empty for no delay.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(tightVertical ? 2 : nil)
            TextField("ms", text: $delayMsText)
                .font(.body.monospacedDigit())
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .frame(maxWidth: 120)
        }
    }

    @ViewBuilder
    private var selectedResponseDocumentationSection: some View {
        if let doc = selectedResponseDocumentation {
            VStack(alignment: .leading, spacing: tightVertical ? 6 : 8) {
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
            .padding(tightVertical ? 10 : 12)
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
                    .lineLimit(tightVertical ? 2 : nil)
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Image(systemName: "curlybraces")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ExplorerPalette.linkAccent)
                TextField("application/json", text: $contentTypeText)
                    .font(.caption.monospaced())
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 140)
                    .focused(focus, equals: .contentType)
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
                ForEach(chipOptions) { opt in
                    let selected = responseChipIsSelected(opt)
                    let primaryHere = chipMatchesServerPrimary(opt)
                    let specEffective = opt.isSpec && specChipIsServerEffective
                    Button {
                        onApplyChip(opt)
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
                        .padding(.horizontal, tightVertical ? 10 : 14)
                        .padding(.vertical, tightVertical ? 7 : 10)
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
            .padding(tightVertical ? 6 : 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ExplorerPalette.chipStripTray)
        )
    }

    private func responseChipIsSelected(_ opt: ResponseChip) -> Bool {
        ResponseChips.chipIsSelected(
            option: opt,
            mock: mock,
            endpoint: endpoint,
            pinnedNumberedResponseChip: pinnedNumberedResponseChip
        )
    }

    private func chipMatchesServerPrimary(_ opt: ResponseChip) -> Bool {
        guard !opt.isSpec, let p = primaryOverride else { return false }
        guard opt.statusCode == p.statusCode,
              MockExamplePresentation.exampleIdsEqual(opt.exampleId, p.exampleId) else { return false }

        if let chipIdx = opt.specResponseListIndex,
           let wantIdx = OverrideListQueries.specResponseListIndexForPrimaryBadge(primary: p, endpoint: endpoint) {
            return chipIdx == wantIdx
        }
        return true
    }

    private var specChipIsServerEffective: Bool {
        primaryOverride == nil
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
