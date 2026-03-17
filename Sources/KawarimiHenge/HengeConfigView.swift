import KawarimiCore
import SwiftUI

/// Server URL バー付きの KawarimiHengeView ラッパー。アプリは serverURL と specProvider 等のクロージャを渡す。
public struct HengeConfigView: View {
    @Binding public var serverURL: String

    private let specProvider: () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding])
    private let fetchOverrides: () async throws -> [MockOverride]
    private let configureOverride: (MockOverride) async throws -> Void
    private let resetAllOverrides: () async throws -> Void

    @State private var refreshTrigger = 0

    public init(
        serverURL: Binding<String>,
        specProvider: @escaping () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding]),
        fetchOverrides: @escaping () async throws -> [MockOverride],
        configureOverride: @escaping (MockOverride) async throws -> Void,
        resetAllOverrides: @escaping () async throws -> Void
    ) {
        self._serverURL = serverURL
        self.specProvider = specProvider
        self.fetchOverrides = fetchOverrides
        self.configureOverride = configureOverride
        self.resetAllOverrides = resetAllOverrides
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            serverURLBar
            Divider()
            KawarimiHengeView(
                specProvider: specProvider,
                fetchOverrides: fetchOverrides,
                configureOverride: configureOverride,
                resetAllOverrides: resetAllOverrides
            )
            .id(refreshTrigger)
        }
    }

    private var serverURLBar: some View {
        HStack {
            Text("Server URL:")
            TextField("http://localhost:8080", text: $serverURL)
                .textFieldStyle(.roundedBorder)
                .onSubmit { refreshTrigger += 1 }
            Button("Refresh") { refreshTrigger += 1 }
            Button("Reset All") {
                Task {
                    try? await resetAllOverrides()
                    refreshTrigger += 1
                }
            }
            .foregroundStyle(.red)
        }
        .padding()
    }
}
