import SwiftUI

struct WebDAVConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: TokenStore
    var onSave: (() -> Void)?

    @State private var serverURL: String
    @State private var username: String
    @State private var password: String
    @State private var path: String
    @State private var isTesting = false
    @State private var testResult: String?

    init(store: TokenStore, onSave: (() -> Void)? = nil) {
        self.store = store
        self.onSave = onSave
        let config = store.settings.webdavConfig
        _serverURL = State(initialValue: config.serverURL)
        _username = State(initialValue: config.username)
        _password = State(initialValue: config.password)
        _path = State(initialValue: config.path)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Credentials") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section("Path") {
                    TextField("Remote path", text: $path)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Label("Test Connection", systemImage: "network")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(serverURL.isEmpty || isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Success") ? .green : .red)
                    }
                }
            }
            .navigationTitle("WebDAV Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.settings.webdavConfig = WebDAVConfig(
                            serverURL: serverURL,
                            username: username,
                            password: password,
                            path: path
                        )
                        store.saveSettings()
                        onSave?()
                        dismiss()
                    }
                }
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        let baseURL = serverURL.hasSuffix("/") ? serverURL : serverURL + "/"
        guard let url = URL(string: baseURL) else {
            testResult = "Invalid URL"
            isTesting = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        let credentials = "\(username):\(password)"
        if let credData = credentials.data(using: .utf8) {
            request.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 207 {
                testResult = "Success — Connection established"
            } else {
                testResult = "Failed — Check credentials"
            }
        } catch {
            testResult = "Error — \(error.localizedDescription)"
        }
        isTesting = false
    }
}
