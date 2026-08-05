import KawarimiCore
import KawarimiHengeCore
import SwiftUI

/// Read-only scenario browser. Lists `kawarimi-scenarios.json` entries fetched from `GET …/__kawarimi/scenarios`.
/// Tapping a resolvable case updates the detail column by `rowId` without leaving the Scenarios tab.
struct ScenarioBrowserView: View {
    let scenarios: [KawarimiScenario]
    let selectedRowId: MockOverrideRowID?
    let canNavigateToOverride: (MockOverrideRowID) -> Bool
    let onNavigateToOverride: (MockOverrideRowID) -> Void

    private var items: [ScenarioBrowserItem] {
        ScenarioBrowserPresentation.items(from: scenarios)
    }

    var body: some View {
        if items.isEmpty {
            scenariosEmptyState
        } else {
            scenarioList
        }
    }

    private var scenariosEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No scenarios loaded")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add a `kawarimi-scenarios.json` beside `kawarimi.json` and reload.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scenarioList: some View {
        List {
            ForEach(items) { item in
                Section {
                    ForEach(item.caseItems) { caseItem in
                        ScenarioCaseRowView(
                            caseItem: caseItem,
                            isSelected: selectedRowId == caseItem.scenarioCase.rowId,
                            canNavigate: canNavigateToOverride(caseItem.scenarioCase.rowId),
                            onNavigateToOverride: onNavigateToOverride
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(ExplorerListRowCardBackground())
                    }
                } header: {
                    ScenarioSectionHeader(item: item)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ExplorerPalette.surface)
    }
}

private struct ScenarioSectionHeader: View {
    let item: ScenarioBrowserItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.scenario.scenarioId)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .tracking(0.2)
            Text("initial: \(item.scenario.initial)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
    }
}

private struct ScenarioCaseRowView: View {
    let caseItem: ScenarioCaseItem
    let isSelected: Bool
    let canNavigate: Bool
    let onNavigateToOverride: (MockOverrideRowID) -> Void

    private var scenarioCase: KawarimiScenarioCase { caseItem.scenarioCase }

    var body: some View {
        Button {
            onNavigateToOverride(scenarioCase.rowId)
        } label: {
            caseRowContent
        }
        .buttonStyle(.plain)
        .disabled(!canNavigate)
        .help(
            canNavigate
                ? "Show override \(scenarioCase.rowId.rawValue) in the detail column"
                : "No matching override for this rowId"
        )
    }

    private var caseRowContent: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(scenarioCase.kawarimiId)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(canNavigate ? .primary : .tertiary)
                    if let next = scenarioCase.next {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(next)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "stop.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                HStack(spacing: 4) {
                    Text(scenarioCase.endpoint.method.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(HTTPMethodBadgeColor.fill(for: .init(scenarioCase.endpoint.method.uppercased()) ?? .get))
                                .opacity(canNavigate ? 1 : 0.45)
                        )
                    Text(scenarioCase.endpoint.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 3) {
                Text(scenarioCase.rowId.rawValue.prefix(8) + "…")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .help("rowId: \(scenarioCase.rowId.rawValue)")
                if !canNavigate {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(ExplorerPalette.linkAccent)
                } else {
                    Image(systemName: "sidebar.right")
                        .font(.caption2)
                        .foregroundStyle(ExplorerPalette.linkAccent)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .opacity(canNavigate ? 1 : 0.7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? ExplorerPalette.linkAccent.opacity(0.12) : .clear)
        )
    }
}
