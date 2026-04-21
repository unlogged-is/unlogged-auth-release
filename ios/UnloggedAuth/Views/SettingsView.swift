import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let store: TokenStore
    let authService: AuthenticationService
    let iconFetcher: ServiceIconFetcher

    @Environment(\.colorScheme) private var colorScheme
    @State private var showChangePassword = false
    @State private var showImport = false
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var showBackupSuccess = false
    @State private var showFilePicker = false
    @State private var importedCount = 0
    @State private var showImportResult = false
    @State private var showBackupPasswordPrompt = false
    @State private var showRestorePasswordPrompt = false
    @State private var backupPassword: String = ""
    @State private var confirmBackupPassword: String = ""
    @State private var restorePassword: String = ""
    @State private var backupError: String?
    @State private var restoreFileData: Data?
    @State private var showBackupExporter = false
    @State private var backupFileData: Data?
    @State private var backupFileName: String = ""
    @State private var showRemoveBiometricConfirm = false
    @State private var showRemovePasswordPrompt = false
    @State private var removePasswordInput: String = ""
    @State private var removePasswordError: String?
    @State private var showExportWarning = false
    @State private var showPlaintextExporter = false
    @State private var plaintextExportData: Data?
    @State private var showExportSuccess = false
    @State private var showExportEmpty = false
    @State private var showPinSetup = false
    @State private var showRemovePinPrompt = false
    @State private var removePinError = false
    @State private var removePinEntryId = UUID()
    @State private var showRemoveDevicePasscodeConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                securitySection
                appearanceSection
                backupSection
                importExportSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .themedBackground()
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(authService: authService, store: store)
        }
        .sheet(isPresented: $showImport) {
            ImportSheet(store: store, iconFetcher: iconFetcher)
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.ulauth, .json, .plainText, .data], allowsMultipleSelection: false) { result in
            handleRestoreFilePick(result)
        }
        .fileExporter(isPresented: $showBackupExporter, document: BackupDocument(data: backupFileData ?? Data()), contentType: .ulauth, defaultFilename: backupFileName) { result in
            handleExportResult(result)
        }
        .alert("Backup Complete", isPresented: $showBackupSuccess) {
            Button("OK") {}
        } message: {
            Text("Your encrypted backup has been saved.")
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            Text("\(importedCount) item\(importedCount == 1 ? "" : "s") imported.")
        }
        .alert("Set Backup Password", isPresented: $showBackupPasswordPrompt) {
            SecureField("Password", text: $backupPassword)
            SecureField("Confirm Password", text: $confirmBackupPassword)
            Button("Cancel", role: .cancel) {
                backupPassword = ""
                confirmBackupPassword = ""
            }
            Button("Create Backup") {
                performEncryptedBackup()
            }
        } message: {
            Text("This password encrypts your backup file. You'll need it to restore.\(backupError.map { "\n\n⚠️ \($0)" } ?? "")")
        }
        .alert("Enter Backup Password", isPresented: $showRestorePasswordPrompt) {
            SecureField("Password", text: $restorePassword)
            Button("Cancel", role: .cancel) {
                restorePassword = ""
                restoreFileData = nil
            }
            Button("Restore") {
                performRestore()
            }
        } message: {
            Text("Enter the password used when creating this backup.\(backupError.map { "\n\n⚠️ \($0)" } ?? "")")
        }
        .alert("Remove Biometric Lock?", isPresented: $showRemoveBiometricConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    if await authService.authenticateWithBiometrics() {
                        store.settings.lockMethod = .none
                        store.saveSettings()
                    }
                }
            }
        } message: {
            Text("You'll need to authenticate with \(authService.biometryName) to confirm. Your tokens will no longer be protected.")
        }
        .alert("Verify Password", isPresented: $showRemovePasswordPrompt) {
            SecureField("Current Password", text: $removePasswordInput)
            Button("Cancel", role: .cancel) {
                removePasswordInput = ""
                removePasswordError = nil
            }
            Button("Remove", role: .destructive) {
                if authService.authenticateWithPassword(removePasswordInput) {
                    authService.clearPassword()
                    store.settings.lockMethod = .none
                    store.saveSettings()
                    removePasswordInput = ""
                    removePasswordError = nil
                } else {
                    removePasswordError = "Incorrect password"
                    removePasswordInput = ""
                    showRemovePasswordPrompt = true
                }
            }
        } message: {
            Text("Enter your current password to remove the lock.\(removePasswordError.map { "\n\n⚠️ \($0)" } ?? "")")
        }
        .alert("Security Warning", isPresented: $showExportWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Export") {
                performPlaintextExport()
            }
        } message: {
            Text("This will export all \(store.tokens.count) token\(store.tokens.count == 1 ? "" : "s") as unencrypted otpauth:// URIs.\n\nAnyone with access to this file can add your accounts to their authenticator app. Store it securely and delete it after use.")
        }
        .alert("Nothing to Export", isPresented: $showExportEmpty) {
            Button("OK") {}
        } message: {
            Text("You don't have any tokens to export. Add some accounts first.")
        }
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK") {}
        } message: {
            Text("Your tokens have been exported. Remember to store the file securely and delete it when you're done.")
        }
        .fileExporter(isPresented: $showPlaintextExporter, document: ExportDocument(data: plaintextExportData ?? Data()), contentType: .plainText, defaultFilename: "unlogged-auth-export.txt") { result in
            if case .success = result {
                showExportSuccess = true
            }
            plaintextExportData = nil
        }
        .sheet(isPresented: $showPinSetup) {
            NavigationStack {
                PinSetupView { pin in
                    authService.setPin(pin)
                    store.settings.lockMethod = .pin
                    store.saveSettings()
                    showPinSetup = false
                } onCancel: {
                    showPinSetup = false
                }
                .navigationTitle(store.settings.lockMethod == .pin ? "Change PIN" : "Set PIN")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showPinSetup = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showRemovePinPrompt) {
            NavigationStack {
                VStack(spacing: 24) {
                    Text("Your tokens will no longer be protected by a PIN.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)

                    PinEntryView(
                        pinLength: authService.storedPinLength(),
                        onComplete: { pin in
                            if authService.authenticateWithPin(pin) {
                                authService.clearPin()
                                store.settings.lockMethod = .none
                                store.saveSettings()
                                showRemovePinPrompt = false
                                removePinError = false
                            } else {
                                removePinError = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    removePinError = false
                                    removePinEntryId = UUID()
                                }
                            }
                        },
                        showError: removePinError,
                        title: "Enter current PIN"
                    )
                    .id(removePinEntryId)
                }
                .navigationTitle("Remove PIN Lock")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showRemovePinPrompt = false
                            removePinError = false
                            removePinEntryId = UUID()
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .alert("Remove Device Passcode Lock?", isPresented: $showRemoveDevicePasscodeConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    if await authService.authenticateWithDevicePasscode() {
                        store.settings.lockMethod = .none
                        store.saveSettings()
                    }
                }
            }
        } message: {
            Text("You'll need to authenticate to confirm. Your tokens will no longer be protected.")
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Section("Security") {
            HStack {
                Label("Lock Method", systemImage: "lock.fill")
                Spacer()
                Text(lockMethodDisplayName)
                    .foregroundStyle(.secondary)
            }

            if store.settings.lockMethod == .biometric {
                Button(role: .destructive) {
                    showRemoveBiometricConfirm = true
                } label: {
                    Label("Remove Biometric Lock", systemImage: "lock.open")
                }
            }

            if store.settings.lockMethod == .password {
                Button {
                    showChangePassword = true
                } label: {
                    Label("Change Password", systemImage: "key.fill")
                }

                Button(role: .destructive) {
                    removePasswordInput = ""
                    removePasswordError = nil
                    showRemovePasswordPrompt = true
                } label: {
                    Label("Remove Password Lock", systemImage: "lock.open")
                }
            }

            if store.settings.lockMethod == .pin {
                Button {
                    showPinSetup = true
                } label: {
                    Label("Change PIN", systemImage: "circle.grid.3x3.fill")
                }

                Button(role: .destructive) {
                    showRemovePinPrompt = true
                } label: {
                    Label("Remove PIN Lock", systemImage: "lock.open")
                }
            }

            if store.settings.lockMethod == .devicePasscode {
                Button(role: .destructive) {
                    showRemoveDevicePasscodeConfirm = true
                } label: {
                    Label("Remove Device Passcode Lock", systemImage: "lock.open")
                }
            }

            if store.settings.lockMethod == .none {
                if authService.isBiometricsAvailable {
                    Button {
                        store.settings.lockMethod = .biometric
                        store.saveSettings()
                    } label: {
                        Label("Enable \(authService.biometryName)", systemImage: authService.biometryIcon)
                    }
                } else {
                    Button {
                        Task {
                            if await authService.authenticateWithDevicePasscode() {
                                store.settings.lockMethod = .devicePasscode
                                store.saveSettings()
                            }
                        }
                    } label: {
                        Label("Enable Device Passcode", systemImage: "lock.rectangle")
                    }
                }

                Button {
                    showPinSetup = true
                } label: {
                    Label("Set PIN", systemImage: "circle.grid.3x3.fill")
                }

                Button {
                    showChangePassword = true
                } label: {
                    Label("Set Password", systemImage: "key.fill")
                }
            }
        }
        .listRowBackground(Color.themedSecondary(for: colorScheme))
    }

    private var lockMethodDisplayName: String {
        switch store.settings.lockMethod {
        case .none: return "None"
        case .biometric: return authService.biometryName
        case .password: return "Password"
        case .pin: return "PIN"
        case .devicePasscode: return "Device Passcode"
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker(selection: Binding(
                get: { store.settings.appTheme },
                set: {
                    store.settings.appTheme = $0
                    store.saveSettings()
                }
            )) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            }

            Toggle(isOn: Binding(
                get: { store.settings.focusSearchOnLaunch },
                set: {
                    store.settings.focusSearchOnLaunch = $0
                    store.saveSettings()
                }
            )) {
                Label("Focus Search on Open", systemImage: "magnifyingglass")
            }
        }
        .listRowBackground(Color.themedSecondary(for: colorScheme))
    }

    @ViewBuilder
    private var backupSection: some View {
        Section("Backup") {
            NavigationLink {
                AutoBackupSettingsView(store: store, authService: authService)
            } label: {
                HStack {
                    Label("Auto-Backup", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Text(store.settings.autoBackupEnabled ? store.settings.backupDestination.displayName : "Off")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                backupError = nil
                backupPassword = ""
                confirmBackupPassword = ""
                showBackupPasswordPrompt = true
            } label: {
                Label("Backup Now", systemImage: "arrow.clockwise")
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Restore from File", systemImage: "square.and.arrow.down")
            }
        }
        .listRowBackground(Color.themedSecondary(for: colorScheme))
    }

    @ViewBuilder
    private var importExportSection: some View {
        Section("Import & Export") {
            Button {
                showImport = true
            } label: {
                Label("Import from Other Apps", systemImage: "square.and.arrow.down.on.square")
            }

            Button {
                if store.tokens.isEmpty {
                    showExportEmpty = true
                } else {
                    showExportWarning = true
                }
            } label: {
                Label("Export Tokens", systemImage: "square.and.arrow.up")
            }
        }
        .listRowBackground(Color.themedSecondary(for: colorScheme))
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"))")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Tokens", systemImage: "key.fill")
                Spacer()
                Text("\(store.tokens.count)")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://unlogged.is")!) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Privacy")
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.accent)
                    }
                    .font(.body)
                    Text("unlogged Auth does not collect any user data. All tokens are encrypted and stored locally on your device. No analytics, no accounts, no cloud services unless you choose to use them.")
                        .font(.caption)
                    HStack(spacing: 6) {
                        Text("Made with 🤍 in Michigan - unlogged.is")
                            .font(.caption)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 4)
            }
        }
        .listRowBackground(Color.themedSecondary(for: colorScheme))
    }

    private func performEncryptedBackup() {
        guard !backupPassword.isEmpty else {
            backupError = "Password cannot be empty"
            showBackupPasswordPrompt = true
            return
        }
        guard backupPassword == confirmBackupPassword else {
            backupError = "Passwords don't match"
            backupPassword = ""
            confirmBackupPassword = ""
            showBackupPasswordPrompt = true
            return
        }

        do {
            let result = try BackupService.createEncryptedBackup(store: store, password: backupPassword)
            authService.setBackupPassword(backupPassword)
            store.settings.hasSetBackupPassword = true
            store.saveSettings()
            backupFileData = result.data
            backupFileName = result.filename
            backupPassword = ""
            confirmBackupPassword = ""
            showBackupExporter = true
        } catch {
            backupError = error.localizedDescription
            showBackupPasswordPrompt = true
        }
    }

    private func performPlaintextExport() {
        guard let data = ExportService.exportAsURIData(tokens: store.tokens) else { return }
        plaintextExportData = data
        showPlaintextExporter = true
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            store.settings.lastBackupDate = Date()
            store.saveSettings()
            showBackupSuccess = true
        case .failure:
            break
        }
        backupFileData = nil
    }

    private func handleRestoreFilePick(_ result: Result<[URL], Error>) {
        guard let urls = try? result.get(), let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }

        if url.pathExtension == "ulauth" {
            restoreFileData = data
            restorePassword = ""
            backupError = nil
            showRestorePasswordPrompt = true
        } else {
            importedCount = store.importData(data)
            showImportResult = true
            iconFetcher.fetchIcons(for: store.tokens)
        }
    }

    private func performRestore() {
        guard let data = restoreFileData else { return }
        do {
            let decrypted = try BackupService.restoreFromBackup(data: data, password: restorePassword)
            importedCount = store.importData(decrypted)
            restoreFileData = nil
            restorePassword = ""
            showImportResult = true
            iconFetcher.fetchIcons(for: store.tokens)
        } catch {
            backupError = error.localizedDescription
            restorePassword = ""
            showRestorePasswordPrompt = true
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.ulauth]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.plainText]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension BackupDestination {
    var displayName: String {
        switch self {
        case .none: return "None"
        case .local: return "Local"
        case .icloud: return "iCloud"
        case .webdav: return "WebDAV"
        }
    }
}
