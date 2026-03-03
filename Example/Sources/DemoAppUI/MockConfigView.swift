import SwiftUI

struct MockConfigView: View {
    @State private var serverURLString = "http://localhost:8080"
    @State private var meta: SpecMeta? = nil
    @State private var endpoints: [SpecEndpoint] = []
    @State private var selectedCodes: [String: Int] = [:]  // key: "METHOD:path", value: statusCode or -1 (disabled)
    @State private var errorMessage: String? = nil
    @State private var isLoading = false

    private var client: AdminAPIClient {
        AdminAPIClient(baseURL: URL(string: serverURLString) ?? URL(string: "http://localhost:8080")!)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            serverURLBar
            Divider()
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                endpointList
            }
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 560, minHeight: 400)
        .task { await refresh() }
    }

    private var serverURLBar: some View {
        HStack {
            Text("Server URL:")
            TextField("http://localhost:8080", text: $serverURLString)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await refresh() } }
            Button("Refresh") { Task { await refresh() } }
            Button("Reset All") { Task { await resetAll() } }
                .foregroundStyle(.red)
        }
        .padding()
    }

    private var endpointList: some View {
        List {
            if let meta {
                Section("API: \(meta.title) v\(meta.version)") {
                    ForEach(endpoints, id: \.operationId) { endpoint in
                        EndpointRow(
                            endpoint: endpoint,
                            selectedCode: Binding(
                                get: { selectedCodes[rowKey(endpoint)] ?? -1 },
                                set: { newValue in
                                    selectedCodes[rowKey(endpoint)] = newValue
                                    Task { await applyOverride(endpoint: endpoint, statusCode: newValue) }
                                }
                            )
                        )
                    }
                }
            } else {
                Text("No spec loaded. Check server URL and refresh.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rowKey(_ endpoint: SpecEndpoint) -> String {
        "\(endpoint.method):\(endpoint.path)"
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            async let specResult = client.fetchSpec()
            async let statusResult = client.fetchStatus()
            let (spec, activeOverrides) = try await (specResult, statusResult)
            meta = spec.meta
            endpoints = spec.endpoints
            var codes: [String: Int] = [:]
            for endpoint in spec.endpoints {
                codes[rowKey(endpoint)] = -1
            }
            for override in activeOverrides where override.isEnabled {
                let key = "\(override.method):\(override.path)"
                codes[key] = override.statusCode
            }
            selectedCodes = codes
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func applyOverride(endpoint: SpecEndpoint, statusCode: Int) async {
        errorMessage = nil
        do {
            if statusCode == -1 {
                let dto = MockOverrideDTO(
                    path: endpoint.path,
                    method: endpoint.method,
                    statusCode: endpoint.responses.first?.statusCode ?? 200,
                    isEnabled: false
                )
                try await client.configure(dto)
            } else {
                let dto = MockOverrideDTO(
                    path: endpoint.path,
                    method: endpoint.method,
                    statusCode: statusCode,
                    isEnabled: true
                )
                try await client.configure(dto)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetAll() async {
        errorMessage = nil
        do {
            try await client.reset()
            for key in selectedCodes.keys {
                selectedCodes[key] = -1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EndpointRow: View {
    let endpoint: SpecEndpoint
    @Binding var selectedCode: Int

    var body: some View {
        HStack {
            Text(endpoint.method)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(endpoint.path)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Picker("Status", selection: $selectedCode) {
                Text("Disabled").tag(-1)
                ForEach(endpoint.responses, id: \.statusCode) { resp in
                    Text("\(resp.statusCode)").tag(resp.statusCode)
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
        .padding(.vertical, 2)
    }
}
