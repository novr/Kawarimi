import KawarimiCore
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

private func validationMessageIsError(_ msg: String) -> Bool {
    msg.hasPrefix("Invalid")
}

private func httpStatusPhrase(_ statusCode: Int) -> String {
    switch statusCode {
    case 100: return "Continue"
    case 200: return "OK"
    case 201: return "Created"
    case 204: return "No Content"
    case 400: return "Bad Request"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 409: return "Conflict"
    case 422: return "Unprocessable Entity"
    case 500: return "Internal Server Error"
    case 502: return "Bad Gateway"
    case 503: return "Service Unavailable"
    default:
        return HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    }
}

// MARK: - Explorer surfaces

private enum ExplorerPalette {
    #if os(iOS)
    private static let lightSurface = UIColor(red: 0.925, green: 0.929, blue: 0.98, alpha: 1)
    private static let lightSurfaceElevated = UIColor(red: 0.949, green: 0.953, blue: 1.0, alpha: 1)
    #endif

    /// List / chrome underlay
    static var surface: Color {
        #if os(iOS)
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? .systemGroupedBackground : lightSurface
        })
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// URL field, search field, raised rows
    static var surfaceElevated: Color {
        #if os(iOS)
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : lightSurfaceElevated
        })
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// URLs and network icon — `link` stays legible on dark grouped backgrounds
    static var linkAccent: Color {
        #if os(iOS)
        Color(UIColor.link)
        #else
        Color(nsColor: .linkColor)
        #endif
    }

    /// Content-type chip etc.
    static var subtleAccentFill: Color {
        Color.accentColor.opacity(0.14)
    }

    /// RESPONSE STATUS chip tray
    static var chipStripTray: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemFill)
        #else
        Color(nsColor: .quaternaryLabelColor).opacity(0.15)
        #endif
    }

    /// Selected status chip (not pure white in dark mode)
    static var chipSelectedFill: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(nsColor: .selectedContentBackgroundColor)
        #endif
    }
}

private var explorerListCardFill: Color {
    ExplorerPalette.surfaceElevated
}

private var groupedFieldStroke: Color {
    #if os(iOS)
    Color(UIColor.separator)
    #else
    Color(nsColor: .separatorColor)
    #endif
}

private extension ToolbarItemPlacement {
    /// `navigationBarTrailing` is unavailable on macOS.
    static var kawarimiTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarTrailing
        #else
        .primaryAction
        #endif
    }
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var store = OverrideEditorStore()
    @State private var confirmResetAll = false
    @State private var searchText = ""
    @State private var compactPath: [EndpointRowKey] = []
    @State private var compactDoneUnsavedPresented = false

    private static let explorerHorizontalMargin: CGFloat = 20

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

    /// Use stack navigation whenever width *or* height is compact. iPhone landscape often reports
    /// `horizontalSizeClass == .regular` while `verticalSizeClass == .compact`, which would pick
    /// `NavigationSplitView` and leave the sidebar drawn over the detail.
    private var useCompactNavigation: Bool {
        #if os(iOS)
        if horizontalSizeClass == .compact { return true }
        if verticalSizeClass == .compact { return true }
        return false
        #else
        horizontalSizeClass == .compact
        #endif
    }

    /// Shorter vertical space (e.g. iPhone landscape): tighter header and detail padding.
    private var explorerTightVertical: Bool {
        #if os(iOS)
        verticalSizeClass == .compact
        #else
        false
        #endif
    }

    private var endpointItems: [SpecEndpointItem] {
        store.endpointItems(endpoints: endpoints)
    }

    private var filteredEndpointItems: [SpecEndpointItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return endpointItems }
        let lower = q.lowercased()
        return endpointItems.filter { item in
            let ep = item.endpoint
            if ep.path.lowercased().contains(lower) { return true }
            if ep.method.rawValue.lowercased().contains(lower) { return true }
            if ep.operationId.lowercased().contains(lower) { return true }
            return false
        }
    }

    private var explorerListRowCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(explorerListCardFill)
            .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 2)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
    }

    var body: some View {
        Group {
            if useCompactNavigation {
                NavigationStack(path: $compactPath) {
                    compactExplorerRoot
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                Label("Explorer", systemImage: "square.grid.2x2")
                                    .font(.headline.weight(.semibold))
                                    .labelStyle(.titleAndIcon)
                            }
                            ToolbarItem(placement: .kawarimiTrailing) {
                                Button("Refresh", action: onRefresh)
                            }
                        }
                        .navigationDestination(for: EndpointRowKey.self) { key in
                            compactDetailDestination(for: key)
                        }
                }
                .onChange(of: compactPath) { _, newPath in
                    if newPath.isEmpty {
                        store.clearSelection()
                    }
                }
            } else {
                NavigationSplitView {
                    splitSidebarContent
                } detail: {
                    splitDetailContent
                }
            }
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
        .confirmationDialog(
            "Unsaved changes",
            isPresented: $compactDoneUnsavedPresented,
            titleVisibility: .visible
        ) {
            Button("Save") {
                Task { await saveAndCompactPopIfSuccess() }
            }
            Button("Discard", role: .destructive) {
                compactPop()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save mock changes before leaving this screen?")
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

    // MARK: - Compact root

    private var compactExplorerRoot: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        explorerHeaderSafeAreaInset
                    }
            } else {
                compactEndpointList
                    .safeAreaInset(edge: .top, spacing: 0) {
                        explorerHeaderSafeAreaInset
                    }
            }
            errorBanner
        }
    }

    private var compactEndpointList: some View {
        List {
            if let meta {
                Section {
                    ForEach(filteredEndpointItems) { item in
                        Button {
                            store.applySelection(item.rowKey, endpoints: endpoints, overrides: overrides)
                            compactPath = [item.rowKey]
                        } label: {
                            EndpointRowView(
                                item: item,
                                statusCode: store.displayedListStatus(for: item.rowKey, overrides: overrides),
                                hasUnsavedDraft: store.detail?.isDirty == true && store.detail?.endpointRowKey == item.rowKey,
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: Self.explorerHorizontalMargin, bottom: 6, trailing: Self.explorerHorizontalMargin))
                        .listRowBackground(explorerListRowCardBackground)
                    }
                } header: {
                    explorerSectionHeader(meta: meta)
                }
            } else {
                Text("No spec loaded. Provide spec via specProvider.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ExplorerPalette.surface)
        .listRowSeparator(.hidden)
    }

    // MARK: - Split sidebar

    private var splitSidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        explorerHeaderSafeAreaInset
                    }
            } else {
                splitEndpointList
                    .safeAreaInset(edge: .top, spacing: 0) {
                        explorerHeaderSafeAreaInset
                    }
            }
            errorBanner
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Label("Explorer", systemImage: "square.grid.2x2")
                    .font(.headline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
            }
            ToolbarItem(placement: .kawarimiTrailing) {
                Button("Refresh", action: onRefresh)
            }
        }
    }

    private var splitEndpointList: some View {
        List(selection: selectionBinding) {
            if let meta {
                Section {
                    ForEach(filteredEndpointItems) { item in
                        EndpointRowView(
                            item: item,
                            statusCode: store.displayedListStatus(for: item.rowKey, overrides: overrides),
                            hasUnsavedDraft: store.detail?.isDirty == true && store.detail?.endpointRowKey == item.rowKey,
                            showChevron: false
                        )
                        .tag(item.rowKey)
                        .listRowInsets(EdgeInsets(top: 6, leading: Self.explorerHorizontalMargin, bottom: 6, trailing: Self.explorerHorizontalMargin))
                        .listRowBackground(explorerListRowCardBackground)
                    }
                } header: {
                    explorerSectionHeader(meta: meta)
                }
            } else {
                Text("No spec loaded. Provide spec via specProvider.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ExplorerPalette.surface)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func explorerSectionHeader(meta: any SpecMetaProviding) -> some View {
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
        .listRowInsets(EdgeInsets(top: 8, leading: Self.explorerHorizontalMargin, bottom: 4, trailing: Self.explorerHorizontalMargin))
    }

    // MARK: - Shared chrome

    /// Pinned above the endpoint `List` via `safeAreaInset` so rows never draw under the search bar.
    private var explorerHeaderSafeAreaInset: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: explorerTightVertical ? 8 : 12) {
                serverStatusCard
                searchField
            }
            .padding(.horizontal, Self.explorerHorizontalMargin)
            .padding(.top, explorerTightVertical ? 4 : 8)
            .padding(.bottom, explorerTightVertical ? 6 : 10)
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(headerChromeBackground)
    }

    private var headerChromeBackground: some View {
        Rectangle()
            .fill(ExplorerPalette.surface)
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
                    .strokeBorder(groupedFieldStroke, lineWidth: 1)
            )

            Button {
                confirmResetAll = true
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
                .strokeBorder(groupedFieldStroke, lineWidth: 1)
        )
    }

    private var errorBanner: some View {
        Group {
            if let error = errorMessage.wrappedValue {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Self.explorerHorizontalMargin)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Detail (split)

    @ViewBuilder
    private var splitDetailContent: some View {
        if let d = store.detail,
           let item = store.specItem(for: d.endpointRowKey, endpoints: endpoints) {
            OverrideDetailColumnView(
                endpointItem: item,
                overrides: overrides,
                mock: mockBinding(for: item),
                validationMessage: validationMessageBinding,
                hasUnsavedChanges: d.isDirty,
                embedNavigationStack: true,
                showToolbarRefresh: true,
                onRefresh: onRefresh,
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

    @ViewBuilder
    private func compactDetailDestination(for key: EndpointRowKey) -> some View {
        if let item = store.specItem(for: key, endpoints: endpoints) {
            OverrideDetailColumnView(
                endpointItem: item,
                overrides: overrides,
                mock: mockBinding(for: item),
                validationMessage: validationMessageBinding,
                hasUnsavedChanges: store.detail?.isDirty == true && store.detail?.endpointRowKey == key,
                embedNavigationStack: false,
                showToolbarRefresh: false,
                onRefresh: onRefresh,
                onValidate: { store.validateBody() },
                onFormat: { store.formatBody() },
                onApply: { Task { await applyWithBody(endpointItem: item) } },
                onReset: { Task { await clearOverride(endpointItem: item) } }
            )
            .onAppear {
                if store.detail?.endpointRowKey != key {
                    store.applySelection(key, endpoints: endpoints, overrides: overrides)
                }
            }
            .navigationTitle("\(item.endpoint.method.rawValue) \(item.endpoint.path)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .kawarimiTrailing) {
                    HStack(spacing: 12) {
                        Button("Refresh", action: onRefresh)
                        Button("Done") {
                            handleCompactDone(for: item)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .tabBar)
            #endif
        } else {
            ContentUnavailableView("Unknown endpoint", systemImage: "questionmark.circle")
                .onAppear {
                    store.applySelection(key, endpoints: endpoints, overrides: overrides)
                }
                #if os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif
        }
    }

    private func handleCompactDone(for item: SpecEndpointItem) {
        guard let d = store.detail, d.endpointRowKey == item.rowKey else {
            compactPop()
            return
        }
        if d.isDirty {
            compactDoneUnsavedPresented = true
        } else {
            compactPop()
        }
    }

    private func compactPop() {
        compactPath = []
        store.clearSelection()
    }

    private func saveAndCompactPopIfSuccess() async {
        guard let key = store.detail?.endpointRowKey,
              let item = store.specItem(for: key, endpoints: endpoints)
        else {
            compactPop()
            return
        }
        await applyWithBody(endpointItem: item)
        if errorMessage.wrappedValue == nil {
            compactPop()
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
    let embedNavigationStack: Bool
    let showToolbarRefresh: Bool
    let onRefresh: () -> Void
    let onValidate: () -> Void
    let onFormat: () -> Void
    let onApply: () -> Void
    let onReset: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var confirmResetEndpoint = false

    private var endpoint: any SpecEndpointProviding { endpointItem.endpoint }

    private var detailTightVertical: Bool {
        #if os(iOS)
        verticalSizeClass == .compact
        #else
        false
        #endif
    }

    private struct MockStatusChipOption: Identifiable {
        let id: Int
        let label: String
    }

    private var mockStatusChipOptions: [MockStatusChipOption] {
        var out = [MockStatusChipOption(id: -1, label: "Spec")]
        var seen = Set<Int>()
        for item in endpointItem.mockResponsePickerItems {
            let c = item.response.statusCode
            if seen.insert(c).inserted {
                out.append(MockStatusChipOption(id: c, label: "\(c) \(httpStatusPhrase(c))"))
            }
        }
        return out
    }

    private var selectedMockStatusCode: Int {
        mock.isEnabled ? mock.statusCode : -1
    }

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
                    Text("RESPONSE STATUS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    Text("Define the HTTP status code returned for this mock.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(detailTightVertical ? 2 : nil)
                    responseStatusChipStrip
                }

                if mock.isEnabled {
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
                                .foregroundStyle(validationMessageIsError(msg) ? .red : .secondary)
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
                ForEach(mockStatusChipOptions) { opt in
                    let selected = selectedMockStatusCode == opt.id
                    Button {
                        responseSelectionBinding.wrappedValue = opt.id
                    } label: {
                        HStack(spacing: 6) {
                            if selected, opt.id != -1 {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                            Text(opt.label)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(
                                    selected
                                        ? (opt.id == -1 ? Color.primary : Color.accentColor)
                                        : Color.secondary
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
                                .strokeBorder(groupedFieldStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(detailTightVertical ? 6 : 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ExplorerPalette.chipStripTray)
        )
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

private struct EndpointRowView: View {
    let item: SpecEndpointItem
    let statusCode: Int
    let hasUnsavedDraft: Bool
    let showChevron: Bool

    private var endpoint: any SpecEndpointProviding { item.endpoint }

    var body: some View {
        HStack(spacing: 10) {
            Text(endpoint.method.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HTTPMethodBadgeColor.fill(for: endpoint.method), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(endpoint.path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
