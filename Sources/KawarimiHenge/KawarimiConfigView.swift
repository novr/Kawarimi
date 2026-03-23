import KawarimiCore
import SwiftUI

/// サーバオリジン用のバーを分離しつつ、タブ間で `apiPathPrefix` を揃えたいとき `apiPathPrefixSync` を渡す。
public struct KawarimiConfigView: View {
    @Binding public var serverURL: String

    private let specProvider: () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding])
    private let fetchOverrides: () async throws -> [MockOverride]
    private let configureOverride: (MockOverride) async throws -> Void
    private let resetAllOverrides: () async throws -> Void
    private let apiPathPrefixSync: Binding<String>?

    @State private var refreshTrigger = 0

    public init(
        serverURL: Binding<String>,
        specProvider: @escaping () async throws -> (meta: any SpecMetaProviding, endpoints: [any SpecEndpointProviding]),
        fetchOverrides: @escaping () async throws -> [MockOverride],
        configureOverride: @escaping (MockOverride) async throws -> Void,
        resetAllOverrides: @escaping () async throws -> Void,
        apiPathPrefixSync: Binding<String>? = nil
    ) {
        self._serverURL = serverURL
        self.specProvider = specProvider
        self.fetchOverrides = fetchOverrides
        self.configureOverride = configureOverride
        self.resetAllOverrides = resetAllOverrides
        self.apiPathPrefixSync = apiPathPrefixSync
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            serverURLBar
            Divider()
            OverrideEditorView(
                specProvider: specProvider,
                fetchOverrides: fetchOverrides,
                configureOverride: configureOverride,
                resetAllOverrides: resetAllOverrides,
                apiPathPrefixSync: apiPathPrefixSync
            )
            .id(refreshTrigger)
        }
    }

    private var serverURLBar: some View {
        HStack {
            Text("Server base URL:")
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
