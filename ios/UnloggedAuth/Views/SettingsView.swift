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
    @State private var showExportChoice = false
    @State private var showExportWarning = false
    @State private var showPlaintextExporter = false
    @State private var plaintextExportData: Data?
    @State private var showExportSuccess = false
    @State private var exportSuccessMessage = ""
    @State private var showExportFailure = false
    @State private var exportFailureMessage = ""
    @State private var showExportEmpty = false
    @State private var showEncryptedExportPassword = false
    @State private var encryptedExportPassword = ""
    @State private var encryptedExportConfirm = ""
    @State private var encryptedExportError: String?
    @State private var showEncryptedExporter = false
    @State private var encryptedExportData: Data?
    @State private var encryptedExportFilename = ""
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
                trashSection
                supportSection
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
        .alert("Set Export Password", isPresented: $showEncryptedExportPassword) {
            SecureField("Password", text: $encryptedExportPassword)
            SecureField("Confirm Password", text: $encryptedExportConfirm)
            Button("Cancel", role: .cancel) {
                encryptedExportPassword = ""
                encryptedExportConfirm = ""
                encryptedExportError = nil
            }
            Button("Export") {
                performEncryptedExport()
            }
        } message: {
            Text("Your tokens will be encrypted with AES-256. You'll need this password to import the file.\(encryptedExportError.map { "\n\n⚠️ \($0)" } ?? "")")
        }
        .alert("Nothing to Export", isPresented: $showExportEmpty) {
            Button("OK") {}
        } message: {
            Text("You don't have any tokens to export. Add some accounts first.")
        }
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK") {}
        } message: {
            Text(exportSuccessMessage)
        }
        .alert("Export Failed", isPresented: $showExportFailure) {
            Button("OK") {}
        } message: {
            Text(exportFailureMessage)
        }
        .fileExporter(isPresented: $showPlaintextExporter, document: ExportDocument(data: plaintextExportData ?? Data()), contentType: .plainText, defaultFilename: "unlogged-auth-export.txt") { result in
            switch result {
            case .success(let url):
                exportSuccessMessage = "Exported \(store.tokens.count) token\(store.tokens.count == 1 ? "" : "s") as plaintext URIs.\n\nSaved to:\n\(url.lastPathComponent)\n\nStore it securely and delete it after use."
                showExportSuccess = true
            case .failure(let error):
                exportFailureMessage = "Could not export tokens.\n\n\(error.localizedDescription)"
                showExportFailure = true
            }
            plaintextExportData = nil
        }
        .fileExporter(isPresented: $showEncryptedExporter, document: BackupDocument(data: encryptedExportData ?? Data()), contentType: .ulauth, defaultFilename: encryptedExportFilename) { result in
            switch result {
            case .success(let url):
                exportSuccessMessage = "Exported \(store.tokens.count) token\(store.tokens.count == 1 ? "" : "s") as an encrypted file.\n\nSaved to:\n\(url.lastPathComponent)\n\nYou'll need your export password to import this file."
                showExportSuccess = true
            case .failure(let error):
                exportFailureMessage = "Could not export tokens.\n\n\(error.localizedDescription)"
                showExportFailure = true
            }
            encryptedExportData = nil
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
        .confirmationDialog("Export Format", isPresented: $showExportChoice, titleVisibility: .visible) {
            Button("Encrypted (.ulauth)") {
                encryptedExportPassword = ""
                encryptedExportConfirm = ""
                encryptedExportError = nil
                showEncryptedExportPassword = true
            }
            Button("Plaintext URIs (.txt)") {
                showExportWarning = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how to export your \(store.tokens.count) token\(store.tokens.count == 1 ? "" : "s").")
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
                    showExportChoice = true
                }
            } label: {
                Label("Export Tokens", systemImage: "square.and.arrow.up")
            }
        }
        .listRowBackground(Color.themedSecondary(for: colorScheme))
    }

    @ViewBuilder
    private var trashSection: some View {
        Section("Trash") {
            Picker(selection: Binding(
                get: { store.settings.trashRetention },
                set: {
                    store.settings.trashRetention = $0
                    store.saveSettings()
                    if $0 == .off {
                        store.emptyTrash()
                    }
                }
            )) {
                ForEach(TrashRetention.allCases, id: \.self) { retention in
                    Text(retention.displayName).tag(retention)
                }
            } label: {
                Label("Auto-Delete After", systemImage: "clock.arrow.circlepath")
            }

            NavigationLink {
                TrashView(store: store)
            } label: {
                HStack {
                    Label("Trash", systemImage: "trash")
                    Spacer()
                    if !store.trashedTokens.isEmpty {
                        Text("\(store.trashedTokens.count)")
                            .foregroundStyle(.secondary)
                    }
                }
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

            Link(destination: URL(string: "https://github.com/unlogged-is/unlogged-auth-release/tree/main")!) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Privacy")
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.accent)
                    }
                    .font(.body)
                    Text("unlogged Auth does not collect any user data. All tokens are encrypted and stored locally on your device. Open source, no analytics, no accounts, no cloud services unless you choose to use them.")
                        .font(.caption)
                    HStack(spacing: 6) {
                        Text("Made with ❤️ in Michigan - github.com")
                            .font(.caption)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                }
                .padding(.vertical, 4)
            }
            .tint(.primary)

        }
        .listRowBackground(Color.themedSecondary(for: colorScheme))
    }

    @ViewBuilder
    private var supportSection: some View {
        Section("Support") {
            Link(destination: URL(string: "https://ko-fi.com/unlogged")!) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        KofiLogo()
                            .fill(Color(red: 1.0, green: 0.392, blue: 0.2))
                            .frame(width: 20, height: 20)
                        Text("Support Development")
                    }
                    .font(.body)
                    Text("unlogged Auth is built and maintained by a solo developer. If you find this app useful, consider buying me a coffee to help support continued development.")
                        .font(.caption)
                    HStack(spacing: 6) {
                        Text("ko-fi.com")
                            .font(.caption)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                }
                .padding(.vertical, 4)
            }
            .tint(.primary)
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

    private func performEncryptedExport() {
        guard !encryptedExportPassword.isEmpty else {
            encryptedExportError = "Password cannot be empty"
            encryptedExportPassword = ""
            encryptedExportConfirm = ""
            showEncryptedExportPassword = true
            return
        }
        guard encryptedExportPassword == encryptedExportConfirm else {
            encryptedExportError = "Passwords don't match"
            encryptedExportPassword = ""
            encryptedExportConfirm = ""
            showEncryptedExportPassword = true
            return
        }
        do {
            let result = try BackupService.createEncryptedBackup(store: store, password: encryptedExportPassword)
            encryptedExportData = result.data
            encryptedExportFilename = result.filename
            encryptedExportPassword = ""
            encryptedExportConfirm = ""
            encryptedExportError = nil
            showEncryptedExporter = true
        } catch {
            encryptedExportError = error.localizedDescription
            encryptedExportPassword = ""
            encryptedExportConfirm = ""
            showEncryptedExportPassword = true
        }
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

struct KofiLogo: Shape {
    private static let svgPath = "M11.351 2.715c-2.7 0-4.986.025-6.83.26C2.078 3.285 0 5.154 0 8.61c0 3.506.182 6.13 1.585 8.493 1.584 2.701 4.233 4.182 7.662 4.182h.83c4.209 0 6.494-2.234 7.637-4a9.5 9.5 0 0 0 1.091-2.338C21.792 14.688 24 12.22 24 9.208v-.415c0-3.247-2.13-5.507-5.792-5.87-1.558-.156-2.65-.208-6.857-.208m0 1.947c4.208 0 5.09.052 6.571.182 2.624.311 4.13 1.584 4.13 4v.39c0 2.156-1.792 3.844-3.87 3.844h-.935l-.156.649c-.208 1.013-.597 1.818-1.039 2.546-.909 1.428-2.545 3.064-5.922 3.064h-.805c-2.571 0-4.831-.883-6.078-3.195-1.09-2-1.298-4.155-1.298-7.506 0-2.181.857-3.402 3.012-3.714 1.533-.233 3.559-.26 6.39-.26m6.547 2.287c-.416 0-.65.234-.65.546v2.935c0 .311.234.545.65.545 1.324 0 2.051-.754 2.051-2s-.727-2.026-2.052-2.026m-10.39.182c-1.818 0-3.013 1.48-3.013 3.142 0 1.533.858 2.857 1.949 3.897.727.701 1.87 1.429 2.649 1.896a1.47 1.47 0 0 0 1.507 0c.78-.467 1.922-1.195 2.623-1.896 1.117-1.039 1.974-2.364 1.974-3.897 0-1.662-1.247-3.142-3.039-3.142-1.065 0-1.792.545-2.338 1.298-.493-.753-1.246-1.298-2.312-1.298"

    func path(in rect: CGRect) -> Path {
        guard let cgPath = SVGPathParser.parse(Self.svgPath) else {
            return Path()
        }
        let boundingBox = cgPath.boundingBox
        let scaleX = rect.width / boundingBox.width
        let scaleY = rect.height / boundingBox.height
        let scale = min(scaleX, scaleY)
        var transform = CGAffineTransform.identity
            .translatedBy(
                x: rect.midX - boundingBox.midX * scale,
                y: rect.midY - boundingBox.midY * scale
            )
            .scaledBy(x: scale, y: scale)
        let scaled = cgPath.copy(using: &transform) ?? cgPath
        return Path(scaled)
    }
}
