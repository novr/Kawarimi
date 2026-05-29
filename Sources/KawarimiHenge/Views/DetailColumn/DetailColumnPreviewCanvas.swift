#if DEBUG
import KawarimiCore
import KawarimiHengeCore
import SwiftUI

/// DEBUG-only; import with `@_spi(Preview) import KawarimiHenge` (Example DemoApp).
@_spi(Preview)
public enum DetailColumnPreviewCanvas {
    @MainActor
    public static func chrome(
        endpoint: any SpecEndpointProviding,
        initialMock: MockOverride,
        securityCatalog: [any SpecSecuritySchemeProviding]? = nil,
        width: CGFloat = 420,
        height: CGFloat = 720
    ) -> some View {
        DetailColumnChromePreviewHost(
            endpoint: endpoint,
            initialMock: initialMock,
            securityCatalog: securityCatalog
        )
        .frame(width: width, height: height)
    }

    @MainActor
    public static func header(
        endpoint: any SpecEndpointProviding,
        initialMock: MockOverride,
        securityCatalog: [any SpecSecuritySchemeProviding]? = nil,
        width: CGFloat = 420
    ) -> some View {
        DetailColumnHeaderPreviewHost(
            endpoint: endpoint,
            initialMock: initialMock,
            securityCatalog: securityCatalog
        )
        .frame(width: width)
    }

    @MainActor
    public static func toolbarTight(width: CGFloat = 420) -> some View {
        DetailColumnToolbarPreviewHost()
            .frame(width: width)
    }
}

private struct DetailColumnChromePreviewHost: View {
    let endpointItem: SpecEndpointItem
    let securityPresentation: EndpointSecurityPresentation
    let chipOptions: [ResponseChip]
    let initialMock: MockOverride

    @State private var mock: MockOverride
    @State private var contentTypeText: String
    @State private var delayMsText = ""
    @State private var confirmResetEndpoint = false
    @FocusState private var detailFocus: DetailColumnFocusField?

    init(
        endpoint: any SpecEndpointProviding,
        initialMock: MockOverride,
        securityCatalog: [any SpecSecuritySchemeProviding]?
    ) {
        let item = SpecEndpointItem(endpoint)
        endpointItem = item
        securityPresentation = SecurityPresentation.endpointPresentation(
            endpoint: endpoint,
            catalog: securityCatalog
        )
        chipOptions = ResponseChips.buildChipOptions(
            mock: initialMock,
            endpointItem: item,
            endpoint: endpoint,
            overrides: [],
            pathPrefix: ""
        )
        self.initialMock = initialMock
        _mock = State(initialValue: initialMock)
        _contentTypeText = State(initialValue: initialMock.contentType ?? "application/json")
    }

    var body: some View {
        DetailColumnScrollStack(
            header: {
                DetailColumnHeaderView(
                    model: DetailColumnHeaderModel(
                        endpointItem: endpointItem,
                        securityPresentation: securityPresentation,
                        chipOptions: chipOptions,
                        primaryOverride: nil,
                        pinnedNumberedResponseChip: false,
                        hasUnsavedChanges: false,
                        tightVertical: false,
                        showResponseBodyHeading: true,
                        selectedResponseDocumentation: nil,
                        canRemoveCurrentMockRow: false
                    ),
                    actions: DetailColumnHeaderActions(
                        onApplyChip: { _ in },
                        onDisableCurrentMock: {},
                        onPresentAddCustom: {}
                    ),
                    bindings: DetailColumnHeaderBindings(
                        mock: $mock,
                        contentTypeText: $contentTypeText,
                        delayMsText: $delayMsText,
                        focus: $detailFocus
                    )
                )
            },
            toolbar: {
                DetailColumnBottomToolbarView(
                    tightVertical: false,
                    onSave: {},
                    confirmResetEndpoint: $confirmResetEndpoint
                )
            }
        )
    }
}

private struct DetailColumnHeaderPreviewHost: View {
    let endpointItem: SpecEndpointItem
    let securityPresentation: EndpointSecurityPresentation
    let chipOptions: [ResponseChip]
    let initialMock: MockOverride

    @State private var mock: MockOverride
    @State private var contentTypeText: String
    @State private var delayMsText = ""
    @FocusState private var focus: DetailColumnFocusField?

    init(
        endpoint: any SpecEndpointProviding,
        initialMock: MockOverride,
        securityCatalog: [any SpecSecuritySchemeProviding]?
    ) {
        let item = SpecEndpointItem(endpoint)
        endpointItem = item
        securityPresentation = SecurityPresentation.endpointPresentation(
            endpoint: endpoint,
            catalog: securityCatalog
        )
        chipOptions = ResponseChips.buildChipOptions(
            mock: initialMock,
            endpointItem: item,
            endpoint: endpoint,
            overrides: [],
            pathPrefix: ""
        )
        self.initialMock = initialMock
        _mock = State(initialValue: initialMock)
        _contentTypeText = State(initialValue: initialMock.contentType ?? "application/json")
    }

    var body: some View {
        DetailColumnHeaderView(
            model: DetailColumnHeaderModel(
                endpointItem: endpointItem,
                securityPresentation: securityPresentation,
                chipOptions: chipOptions,
                primaryOverride: nil,
                pinnedNumberedResponseChip: false,
                hasUnsavedChanges: false,
                tightVertical: false,
                showResponseBodyHeading: true,
                selectedResponseDocumentation: nil,
                canRemoveCurrentMockRow: false
            ),
            actions: DetailColumnHeaderActions(
                onApplyChip: { _ in },
                onDisableCurrentMock: {},
                onPresentAddCustom: {}
            ),
            bindings: DetailColumnHeaderBindings(
                mock: $mock,
                contentTypeText: $contentTypeText,
                delayMsText: $delayMsText,
                focus: $focus
            )
        )
    }
}

private struct DetailColumnToolbarPreviewHost: View {
    @State private var confirmResetEndpoint = false

    var body: some View {
        DetailColumnBottomToolbarView(
            tightVertical: true,
            onSave: {},
            confirmResetEndpoint: $confirmResetEndpoint
        )
    }
}
#endif
