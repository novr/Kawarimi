import KawarimiCore
import SwiftUI

/// Endpoint explorer and detail editor; list/spec inputs from the parent, draft state in ``OverrideEditorStore``.
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
    private let configureOverride: (MockOverride) async throws -> [MockOverride]
    private let removeOverride: (MockOverride) async throws -> [MockOverride]
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
        configureOverride: @escaping (MockOverride) async throws -> [MockOverride],
        removeOverride: @escaping (MockOverride) async throws -> [MockOverride],
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

    private var useCompactNavigation: Bool {
        NavigationLayoutLogic.useCompactNavigation(horizontal: horizontalSizeClass, vertical: verticalSizeClass)
    }

    private var explorerTightVertical: Bool {
        NavigationLayoutLogic.explorerTightVertical(vertical: verticalSizeClass)
    }

    private var specPathPrefix: String { meta?.apiPathPrefix ?? "" }

    /// iOS: always inline under the server card. macOS compact: `.searchable` on the navigation stack.
    /// macOS split: sidebar `.searchable` is unreliable without room; inline field stays visible in ``ExplorerTopInset``.
    private var explorerShowsInlineSearch: Bool {
        #if os(iOS)
        true
        #elseif os(macOS)
        !useCompactNavigation
        #else
        false
        #endif
    }

    private var endpointItems: [SpecEndpointItem] {
        store.endpointItems(endpoints: endpoints)
    }

    private var filteredEndpointItems: [SpecEndpointItem] {
        EndpointFilter.filter(endpointItems, searchText: searchText)
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
                        #if os(macOS)
                        .searchable(
                            text: $searchText,
                            prompt: Text("Search endpoints, methods, or descriptions")
                        )
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
                    NavigationStack {
                        splitSidebarContent
                    }
                    .navigationSplitViewColumnWidth(min: 280, ideal: 380, max: 560)
                } detail: {
                    splitDetailContent
                }
            }
        }
        .task(id: specLoadID) {
            store.resyncDetailAfterSpecReload(pathPrefix: specPathPrefix, endpoints: endpoints, overrides: overrides)
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
            set: { store.setDetailValidationMessage($0) }
        )
    }

    /// Subtitle: **server primary** example label (list is never driven by unsaved draft selection).
    private func endpointListExampleCaption(rowKey: EndpointRowKey, item: SpecEndpointItem) -> String? {
        let opId = item.endpoint.operationId
        let code = store.displayedListStatus(for: rowKey, operationId: opId, pathPrefix: specPathPrefix, overrides: overrides)
        guard code != -1 else { return nil }
        let exId = OverrideListQueries.primaryEnabledOverride(
            for: rowKey,
            operationId: opId,
            pathPrefix: specPathPrefix,
            in: overrides
        )?.exampleId
        let choices = item.mockResponsePickerItems.filter { $0.response.statusCode == code }
        if let pick = MockExamplePresentation.matchingPickerItem(exampleId: exId, in: choices) {
            return MockExamplePresentation.label(for: pick.response)
        }
        if let raw = exId?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        return nil
    }

    private func primaryOverride(for item: SpecEndpointItem) -> MockOverride? {
        OverrideListQueries.primaryEnabledOverride(
            for: item.rowKey,
            operationId: item.endpoint.operationId,
            pathPrefix: specPathPrefix,
            in: overrides
        )
    }

    private func showsMultipleActiveMocksWarning(for item: SpecEndpointItem) -> Bool {
        OverrideListQueries.hasMultipleEnabledOverridesForOperation(
            rowKey: item.rowKey,
            operationId: item.endpoint.operationId,
            pathPrefix: specPathPrefix,
            in: overrides
        )
    }

    private var selectionBinding: Binding<EndpointRowKey?> {
        Binding(
            get: { store.selectedRowKey },
            set: { store.applySelection($0, pathPrefix: specPathPrefix, endpoints: endpoints, overrides: overrides) }
        )
    }

    // MARK: - Compact root

    private var compactExplorerRoot: some View {
        VStack(alignment: .leading, spacing: 0) {
            explorerChromeHeader
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    compactEndpointList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            errorBanner
        }
    }

    private var compactEndpointList: some View {
        List {
            if let meta {
                Section {
                    ForEach(filteredEndpointItems) { item in
                        Button {
                            store.applySelection(item.rowKey, pathPrefix: specPathPrefix, endpoints: endpoints, overrides: overrides)
                            compactPath = [item.rowKey]
                        } label: {
                            EndpointRowView(
                                item: item,
                                statusCode: store.displayedListStatus(
                                    for: item.rowKey,
                                    operationId: item.endpoint.operationId,
                                    pathPrefix: specPathPrefix,
                                    overrides: overrides
                                ),
                                exampleCaption: endpointListExampleCaption(rowKey: item.rowKey, item: item),
                                hasUnsavedDraft: store.hasUnsavedDraft(
                                    for: item.rowKey,
                                    pathPrefix: specPathPrefix,
                                    endpoints: endpoints,
                                    overrides: overrides
                                ),
                                showMultipleActiveMocksWarning: showsMultipleActiveMocksWarning(for: item),
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: Self.explorerHorizontalMargin, bottom: 6, trailing: Self.explorerHorizontalMargin))
                        .listRowBackground(ExplorerListRowCardBackground())
                    }
                } header: {
                    ExplorerListHeader(meta: meta, horizontalMargin: Self.explorerHorizontalMargin)
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
        .id(overridesRevision)
    }

    // MARK: - Split sidebar

    private var splitSidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            explorerChromeHeader
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    splitEndpointList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                                pathPrefix: specPathPrefix,
                                overrides: overrides
                            ),
                            exampleCaption: endpointListExampleCaption(rowKey: item.rowKey, item: item),
                            hasUnsavedDraft: store.hasUnsavedDraft(
                                for: item.rowKey,
                                pathPrefix: specPathPrefix,
                                endpoints: endpoints,
                                overrides: overrides
                            ),
                            showMultipleActiveMocksWarning: showsMultipleActiveMocksWarning(for: item),
                            showChevron: false
                        )
                        .tag(item.rowKey)
                        .listRowInsets(EdgeInsets(top: 6, leading: Self.explorerHorizontalMargin, bottom: 6, trailing: Self.explorerHorizontalMargin))
                        .listRowBackground(ExplorerListRowCardBackground())
                    }
                } header: {
                    ExplorerListHeader(meta: meta, horizontalMargin: Self.explorerHorizontalMargin)
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
        .id(overridesRevision)
    }

    // MARK: - Shared chrome

    private var explorerChromeHeader: some View {
        ExplorerTopInset(
            serverURL: serverURL,
            searchText: $searchText,
            explorerTightVertical: explorerTightVertical,
            horizontalMargin: Self.explorerHorizontalMargin,
            onRequestResetAll: { confirmResetAll = true },
            showsInlineSearch: explorerShowsInlineSearch
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
                apiPathPrefix: specPathPrefix,
                primaryOverride: primaryOverride(for: item),
                mock: mockBinding(for: item),
                validationMessage: validationMessageBinding,
                hasUnsavedChanges: store.hasUnsavedDraft(
                    for: d.endpointRowKey,
                    pathPrefix: specPathPrefix,
                    endpoints: endpoints,
                    overrides: overrides
                ),
                embedNavigationStack: true,
                showToolbarRefresh: true,
                onRefresh: onRefresh,
                onValidate: { store.validateBody() },
                onFormat: { store.formatBody() },
                onSave: { Task { await applyWithBody(endpointItem: item) } },
                onReset: { Task { await clearOverride(endpointItem: item) } },
                onDisableCurrentMock: { Task { await disableCurrentMockRow(endpointItem: item) } },
                pinnedNumberedResponseChip: store.pinnedNumberedResponseChip(for: d.endpointRowKey),
                onResponseChipSelected: syncPinnedNumberedResponseChip(afterSelecting:)
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
                apiPathPrefix: specPathPrefix,
                primaryOverride: primaryOverride(for: item),
                mock: mockBinding(for: item),
                validationMessage: validationMessageBinding,
                hasUnsavedChanges: store.hasUnsavedDraft(
                    for: key,
                    pathPrefix: specPathPrefix,
                    endpoints: endpoints,
                    overrides: overrides
                ),
                embedNavigationStack: false,
                showToolbarRefresh: false,
                onRefresh: onRefresh,
                onValidate: { store.validateBody() },
                onFormat: { store.formatBody() },
                onSave: { Task { await applyWithBody(endpointItem: item) } },
                onReset: { Task { await clearOverride(endpointItem: item) } },
                onDisableCurrentMock: { Task { await disableCurrentMockRow(endpointItem: item) } },
                pinnedNumberedResponseChip: store.pinnedNumberedResponseChip(for: key),
                onResponseChipSelected: syncPinnedNumberedResponseChip(afterSelecting:)
            )
            .onAppear {
                if store.detail?.endpointRowKey != key {
                    store.applySelection(key, pathPrefix: specPathPrefix, endpoints: endpoints, overrides: overrides)
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
                    store.applySelection(key, pathPrefix: specPathPrefix, endpoints: endpoints, overrides: overrides)
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
        if store.hasUnsavedDraft(
            for: item.rowKey,
            pathPrefix: specPathPrefix,
            endpoints: endpoints,
            overrides: overrides
        ) {
            compactDoneUnsavedPresented = true
        } else {
            compactPop()
        }
    }

    private func compactPop() {
        compactPath = []
        store.clearSelection()
    }

    private func syncPinnedNumberedResponseChip(afterSelecting chip: ResponseChip) {
        store.setPinnedNumberedResponseChip(!chip.isSpec)
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
        Binding(
            get: { store.detail?.mock ?? MockDraftDefaults.specPlaceholder(for: item) },
            set: { store.applyMockEdit(from: item, newMock: $0) }
        )
    }

    private func applyWithBody(endpointItem: SpecEndpointItem) async {
        await store.applyWithBody(
            endpointItem: endpointItem,
            pathPrefix: specPathPrefix,
            endpoints: endpoints,
            configureOverride: configureOverride,
            setErrorMessage: { errorMessage.wrappedValue = $0 }
        )
    }

    private func clearOverride(endpointItem: SpecEndpointItem) async {
        await store.clearOverride(
            endpointItem: endpointItem,
            pathPrefix: specPathPrefix,
            endpoints: endpoints,
            configureOverride: configureOverride,
            setErrorMessage: { errorMessage.wrappedValue = $0 }
        )
    }

    private func disableCurrentMockRow(endpointItem: SpecEndpointItem) async {
        await store.disableCurrentMockRow(
            endpointItem: endpointItem,
            pathPrefix: specPathPrefix,
            overrides: overrides,
            endpoints: endpoints,
            configureOverride: configureOverride,
            removeOverride: removeOverride,
            setErrorMessage: { errorMessage.wrappedValue = $0 }
        )
    }
}
