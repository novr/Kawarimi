import KawarimiCore
import SwiftUI

struct OverrideExplorerSectionHeader: View {
    let meta: any SpecMetaProviding
    let horizontalMargin: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AVAILABLE ENDPOINTS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text("API: \(meta.title) v\(meta.version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: horizontalMargin, bottom: 4, trailing: horizontalMargin))
    }
}

struct OverrideExplorerHeaderInset: View {
    let serverURL: String
    @Binding var searchText: String
    let explorerTightVertical: Bool
    let horizontalMargin: CGFloat
    let onRequestResetAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: explorerTightVertical ? 8 : 12) {
                serverStatusCard
                searchField
            }
            .padding(.horizontal, horizontalMargin)
            .padding(.top, explorerTightVertical ? 4 : 8)
            .padding(.bottom, explorerTightVertical ? 6 : 10)
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Rectangle().fill(ExplorerPalette.surface))
    }

    private var serverStatusCard: some View {
        VStack(alignment: .leading, spacing: explorerTightVertical ? 8 : 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "network")
                    .font(.body.weight(.medium))
                    .foregroundStyle(ExplorerPalette.linkAccent)
                Text(serverURL)
                    .font(.body.monospaced())
                    .foregroundStyle(ExplorerPalette.linkAccent)
                    .lineLimit(explorerTightVertical ? 2 : 3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(explorerTightVertical ? 8 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ExplorerPalette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
            )

            Button {
                onRequestResetAll()
            } label: {
                Label("Reset all overrides", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .controlSize(explorerTightVertical ? .small : .regular)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search endpoints, methods, or descriptions", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(explorerTightVertical ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ExplorerPalette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ExplorerPalette.groupedFieldStroke, lineWidth: 1)
        )
    }
}

struct EndpointRowView: View {
    let item: SpecEndpointItem
    let statusCode: Int
    let exampleCaption: String?
    let hasUnsavedDraft: Bool
    let showChevron: Bool

    private var endpoint: any SpecEndpointProviding { item.endpoint }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(endpoint.method.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HTTPMethodBadgeColor.fill(for: endpoint.method), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(endpoint.path)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let exampleCaption {
                    Text(exampleCaption)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if hasUnsavedDraft {
                    Text("Unsaved")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Group {
                    if statusCode == -1 {
                        Text("Spec")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("\(statusCode)")
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .frame(minWidth: 52, alignment: .trailing)
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
