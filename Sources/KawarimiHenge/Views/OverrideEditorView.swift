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
    private let removeOverride: (MockOverride) async throws -> Void
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
        removeOverride: @escaping (MockOverride) async throws -> Void,
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
        self.removeOverride = removeOverride
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
        @Bindable var store = store
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
            store.apiPathPrefix = meta?.apiPathPrefix ?? OpenAPIPathPrefix.defaultMountPath
            store.resyncDetailAfterSpecReload(endpoints: endpoints, overrides: overrides)
        }
        .task(id: overridesRevision) {
            store.apiPathPrefix = meta?.apiPathPrefix ?? OpenAPIPathPrefix.defaultMountPath
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

    /// Subtitle under the path when a mock is on: which OpenAPI example body is selected (`Default` or named).
    private func endpointListExampleCaption(rowKey: EndpointRowKey, item: SpecEndpointItem) -> String? {
        let opId = item.endpoint.operationId
        let code = store.displayedListStatus(for: rowKey, operationId: opId, overrides: overrides)
        guard code != -1 else { return nil }
        let exId: String?
        if let d = store.detail, d.endpointRowKey == rowKey, d.mock.isEnabled {
            exId = d.mock.exampleId
        } else {
            exId = OverrideListQueries.primaryEnabledOverride(
                for: rowKey,
                operationId: opId,
                pathPrefix: store.apiPathPrefix,
                in: overrides
            )?.exampleId
        }
        let choices = item.mockResponsePickerItems.filter { $0.response.statusCode == code }
        if let pick = MockExamplePresentation.matchingPickerItem(exampleId: exId, in: choices) {
            return MockExamplePresentation.label(for: pick.response)
        }
        if let raw = exId?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        return nil
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
                                statusCode: store.displayedListStatus(
                                    for: item.rowKey,
                                    operationId: item.endpoint.operationId,
                                    overrides: overrides
                                ),
                                exampleCaption: endpointListExampleCaption(rowKey: item.rowKey, item: item),
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
                            statusCode: store.displayedListStatus(
                                for: item.rowKey,
                                operationId: item.endpoint.operationId,
                                overrides: overrides
                            ),
                            exampleCaption: endpointListExampleCaption(rowKey: item.rowKey, item: item),
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
                apiPathPrefix: store.apiPathPrefix,
                mock: mockBinding(for: item),
                validationMessage: validationMessageBinding,
                hasUnsavedChanges: d.isDirty,
                embedNavigationStack: true,
                showToolbarRefresh: true,
                onRefresh: onRefresh,
                onValidate: { store.validateBody() },
                onFormat: { store.formatBody() },
                onApply: { Task { await applyWithBody(endpointItem: item) } },
                onReset: { Task { await clearOverride(endpointItem: item) } },
                onDisableCurrentMock: { Task { await disableCurrentMockRow(endpointItem: item) } }
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
                apiPathPrefix: store.apiPathPrefix,
                mock: mockBinding(for: item),
                validationMessage: validationMessageBinding,
                hasUnsavedChanges: store.detail?.isDirty == true && store.detail?.endpointRowKey == key,
                embedNavigationStack: false,
                showToolbarRefresh: false,
                onRefresh: onRefresh,
                onValidate: { store.validateBody() },
                onFormat: { store.formatBody() },
                onApply: { Task { await applyWithBody(endpointItem: item) } },
                onReset: { Task { await clearOverride(endpointItem: item) } },
                onDisableCurrentMock: { Task { await disableCurrentMockRow(endpointItem: item) } }
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
                        exampleId: nil,
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
        guard var draft = store.detail, draft.endpointRowKey == endpointItem.rowKey else { return }
        let m = draft.mock
        // Save turns the override on when the draft is a concrete response choice (not “Spec only”):
        // - Mock active toggle on, or
        // - A saved row for this status/example (e.g. was disabled — selecting + Save re-enables), or
        // - A response shape not in the OpenAPI list (custom status / example id) so “selection” implies an override.
        let hasRow = OverrideListQueries.hasStoredRowMatchingDraft(
            m,
            rowKey: endpointItem.rowKey,
            operationId: endpoint.operationId,
            pathPrefix: store.apiPathPrefix,
            in: overrides
        )
        let isListedInSpec = OverrideListQueries.specContainsResponse(
            endpoint,
            statusCode: m.statusCode,
            exampleId: m.exampleId
        )
        let enabled = m.isEnabled || hasRow || !isListedInSpec
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
                exampleId: enabled ? m.exampleId : nil,
                isEnabled: enabled,
                body: body,
                contentType: contentType
            )
            try await configureOverride(override)
            draft.mock.isEnabled = override.isEnabled
            draft.mock.statusCode = override.statusCode
            draft.mock.exampleId = override.exampleId
            draft.mock.body = override.body
            draft.mock.contentType = override.contentType
            store.commitDetail(draft)
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
                exampleId: nil,
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

    /// When active: persist `isEnabled: false` for this row. When already disabled: remove the row from config.
    private func disableCurrentMockRow(endpointItem: SpecEndpointItem) async {
        let endpoint = endpointItem.endpoint
        errorMessage.wrappedValue = nil
        guard let draft = store.detail, draft.endpointRowKey == endpointItem.rowKey else { return }
        let m = draft.mock
        let hasRow = OverrideListQueries.hasStoredRowMatchingDraft(
            m,
            rowKey: endpointItem.rowKey,
            operationId: endpoint.operationId,
            pathPrefix: store.apiPathPrefix,
            in: overrides
        )
        let key = MockOverride(
            name: endpoint.operationId,
            path: endpoint.path,
            method: endpoint.method,
            statusCode: m.statusCode,
            exampleId: m.exampleId,
            isEnabled: false,
            body: nil,
            contentType: nil
        )
        do {
            if m.isEnabled {
                try await configureOverride(key)
                store.markSavedClean()
            } else if hasRow {
                try await removeOverride(key)
                let cleared = MockOverride(
                    name: endpoint.operationId,
                    path: endpoint.path,
                    method: endpoint.method,
                    statusCode: endpoint.responseList.first?.statusCode ?? 200,
                    exampleId: nil,
                    isEnabled: false,
                    body: nil,
                    contentType: nil
                )
                store.applyServerReset(mock: cleared, rowKey: endpointItem.rowKey)
                store.markSavedClean()
            }
        } catch {
            errorMessage.wrappedValue = error.localizedDescription
        }
    }
}

private struct OverrideDetailColumnView: View {
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
    /// Stable example id for the row being composed in the sheet (one per presentation).
    @State private var addCustomScratchExampleId: String = ""

    /// Common HTTP statuses for the Add sheet; any code already present on this operation in the spec is omitted from the picker.
    private static let commonCustomStatusCodes: [Int] = [
        100, 101, 103,
        200, 201, 202, 203, 204, 205, 206, 207, 208, 226,
        300, 301, 302, 303, 304, 307, 308,
        400, 401, 402, 403, 404, 405, 406, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 421, 422, 423, 424, 425, 426, 428, 429, 431, 451,
        500, 501, 502, 503, 504, 505, 506, 507, 508, 510, 511,
    ]

    /// All picker codes (same HTTP status as the spec is allowed: new rows are distinguished by `exampleId`).
    private var addCustomStatusPickerCandidates: [Int] {
        Self.commonCustomStatusCodes
    }

    private var endpoint: any SpecEndpointProviding { endpointItem.endpoint }

    private var detailTightVertical: Bool {
        #if os(iOS)
        verticalSizeClass == .compact
        #else
        false
        #endif
    }

    private struct MockStatusChipOption: Identifiable {
        static let specRowId = "spec"

        /// Stable row id: ``specRowId`` or ``SpecMockResponseProviding/id``.
        let id: String
        let statusCode: Int
        let exampleId: String?
        let label: String
        /// Saved custom row with `isEnabled: false` (still editable).
        let isInactive: Bool

        var isSpec: Bool { id == Self.specRowId }
    }

    /// One chip per OpenAPI mock row (same HTTP status can appear multiple times for different `exampleId`s),
    /// plus custom overrides not listed in the spec (enabled and disabled).
    private var mockStatusChipOptions: [MockStatusChipOption] {
        var out: [MockStatusChipOption] = [
            MockStatusChipOption(
                id: MockStatusChipOption.specRowId,
                statusCode: -1,
                exampleId: nil,
                label: "Spec",
                isInactive: false
            ),
        ]
        for item in endpointItem.mockResponsePickerItems {
            let r = item.response
            let c = r.statusCode
            let exLabel = MockExamplePresentation.label(for: r)
            let label: String
            if MockExamplePresentation.normalizedExampleId(r.exampleId) != nil {
                label = "\(c) · \(exLabel)"
            } else {
                label = "\(c) \(httpStatusPhrase(c))"
            }
            out.append(MockStatusChipOption(id: item.id, statusCode: c, exampleId: r.exampleId, label: label, isInactive: false))
        }
        let customs = OverrideListQueries.customOverrides(
            for: endpointItem.rowKey,
            endpoint: endpoint,
            operationId: endpoint.operationId,
            pathPrefix: apiPathPrefix,
            in: overrides
        )
        let sortedCustoms = MockOverride.sortedForInterceptorTieBreak(customs)
        for ov in sortedCustoms {
            let id = Self.supplementalRowChipId(statusCode: ov.statusCode, exampleId: ov.exampleId)
            let label = Self.supplementalChipLabel(statusCode: ov.statusCode, exampleId: ov.exampleId)
            out.append(
                MockStatusChipOption(
                    id: id,
                    statusCode: ov.statusCode,
                    exampleId: ov.exampleId,
                    label: label,
                    isInactive: !ov.isEnabled
                )
            )
        }
        // Local draft (not yet on server): otherwise no chip matches and the detail looks unchanged.
        if mock.isEnabled,
           !OverrideListQueries.specContainsResponse(endpoint, statusCode: mock.statusCode, exampleId: mock.exampleId)
        {
            let draftId = Self.supplementalRowChipId(statusCode: mock.statusCode, exampleId: mock.exampleId)
            let alreadyListed = out.contains { opt in
                !opt.isSpec && opt.statusCode == mock.statusCode
                    && MockExamplePresentation.exampleIdsEqual(opt.exampleId, mock.exampleId)
            }
            if !alreadyListed {
                let label = Self.supplementalChipLabel(statusCode: mock.statusCode, exampleId: mock.exampleId)
                out.append(
                    MockStatusChipOption(
                        id: draftId,
                        statusCode: mock.statusCode,
                        exampleId: mock.exampleId,
                        label: label,
                        isInactive: false
                    )
                )
            }
        }
        return out
    }

    private static func supplementalChipLabel(statusCode: Int, exampleId: String?) -> String {
        if let ex = MockExamplePresentation.normalizedExampleId(exampleId) {
            return "\(statusCode) · \(ex)"
        }
        return "\(statusCode) \(httpStatusPhrase(statusCode))"
    }

    private static func supplementalRowChipId(statusCode: Int, exampleId: String?) -> String {
        let ex = MockExamplePresentation.normalizedExampleId(exampleId).map { $0 } ?? "_default"
        return "supplemental:\(statusCode):\(ex)"
    }

    private func responseOptionExists(statusCode: Int, exampleId: String?) -> Bool {
        mockStatusChipOptions.contains { opt in
            !opt.isSpec && opt.statusCode == statusCode && MockExamplePresentation.exampleIdsEqual(opt.exampleId, exampleId)
        }
    }

    private func responseChipIsSelected(_ opt: MockStatusChipOption) -> Bool {
        if opt.isSpec {
            if mock.isEnabled { return false }
            return !OverrideListQueries.hasStoredRowMatchingDraft(
                mock,
                rowKey: endpointItem.rowKey,
                operationId: endpoint.operationId,
                pathPrefix: apiPathPrefix,
                in: overrides
            )
        }
        return mock.statusCode == opt.statusCode
            && MockExamplePresentation.exampleIdsEqual(mock.exampleId, opt.exampleId)
    }

    private func applyResponseChip(_ opt: MockStatusChipOption) {
        var m = mock
        if opt.isSpec {
            m.isEnabled = false
            m.statusCode = endpoint.responseList.first?.statusCode ?? 200
            m.exampleId = nil
            m.body = nil
            m.contentType = nil
        } else if let stored = OverrideListQueries.storedOverride(
            for: endpointItem.rowKey,
            operationId: endpoint.operationId,
            pathPrefix: apiPathPrefix,
            statusCode: opt.statusCode,
            exampleId: opt.exampleId,
            in: overrides
        ) {
            m.isEnabled = stored.isEnabled
            m.statusCode = stored.statusCode
            m.exampleId = stored.exampleId
            m.name = stored.name ?? endpoint.operationId
            if stored.hasEffectiveCustomBody {
                m.body = stored.body
                m.contentType = stored.contentType
            } else {
                mergeResponseTemplate(
                    endpoint: endpoint,
                    overrides: overrides,
                    pathPrefix: apiPathPrefix,
                    statusCode: opt.statusCode,
                    into: &m
                )
            }
        } else {
            m.isEnabled = true
            m.statusCode = opt.statusCode
            m.exampleId = opt.exampleId
            mergeResponseTemplate(
                endpoint: endpoint,
                overrides: overrides,
                pathPrefix: apiPathPrefix,
                statusCode: opt.statusCode,
                into: &m
            )
        }
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

    /// Minus: disable when active, or delete row from config when already disabled (if a saved row exists).
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
                                Text("\(code) \(httpStatusPhrase(code))")
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
                                .strokeBorder(groupedFieldStroke, lineWidth: 1)
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

    private func copyChipExampleIdToPasteboard(_ opt: MockStatusChipOption) {
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

private struct EndpointRowView: View {
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
