import SwiftUI

struct AutoBackupSettingsView: View {
    let store: TokenStore
    let authService: AuthenticationService
    @Environment(\.colorScheme) private var colorScheme
    @State private var showWebDAVConfig = false
    @State private var showSetPassword = false
    @State private var showChangePassword = false
    @State private var backupPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var pendingEnable = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { store.settings.autoBackupEnabled },
                    set: { newValue in
                        if newValue {
                            // Require a backup password before enabling
                            if authService.hasBackupPassword() {
                                store.settings.autoBackupEnabled = true
                                store.saveSettings()
                            } else {
                                pendingEnable = true
                                passwordError = nil
                                backupPassword = ""
                                confirmPassword = ""
                                showSetPassword = true
                            }
                        } else {
                            store.settings.autoBackupEnabled = false
                            store.settings.backupDestination = .none
                            store.saveSettings()
                        }
                    }
                )) {
                    Label("Auto-Backup", systemImage: "arrow.triangle.2.circlepath")
                }
            } footer: {
                Text("When enabled, your tokens are automatically backed up to the selected destination. The backup file is encrypted and overwritten each time.")
            }
            .listRowBackground(Color.themedSecondary(for: colorScheme))

            if store.settings.autoBackupEnabled {
                Section("Destination") {
                    destinationRow(
                        icon: "internaldrive.fill",
                        title: "Local Storage",
                        subtitle: "Saved to \"unlogged Auth\" folder on this device",
                        destination: .local,
                        color: .green
                    )

                    destinationRow(
                        icon: "icloud.fill",
                        title: "iCloud Drive",
                        subtitle: "Saved to \"unlogged Auth\" folder in iCloud",
                        destination: .icloud,
                        color: .blue
                    )

                    destinationRow(
                        icon: "server.rack",
                        title: "WebDAV Server",
                        subtitle: "Self-hosted Nextcloud or WebDAV server",
                        destination: .webdav,
                        color: .purple
                    )
                }
                .listRowBackground(Color.themedSecondary(for: colorScheme))

                if store.settings.backupDestination == .webdav {
                    Section {
                        Button {
                            showWebDAVConfig = true
                        } label: {
                            HStack {
                                Label("Configure WebDAV", systemImage: "gear")
                                Spacer()
                                if !store.settings.webdavConfig.serverURL.isEmpty {
                                    Text(store.settings.webdavConfig.serverURL)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .listRowBackground(Color.themedSecondary(for: colorScheme))
                }

                Section("Encryption") {
                    HStack {
                        Label("Backup Password", systemImage: "lock.fill")
                        Spacer()
                        Text("Set")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        passwordError = nil
                        backupPassword = ""
                        confirmPassword = ""
                        pendingEnable = false
                        showChangePassword = true
                    } label: {
                        Label("Change Backup Password", systemImage: "key.fill")
                    }
                }
                .listRowBackground(Color.themedSecondary(for: colorScheme))

                if let lastBackup = store.settings.lastBackupDate {
                    Section {
                        HStack {
                            Label("Last Backup", systemImage: "clock")
                            Spacer()
                            Text(lastBackup, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.themedSecondary(for: colorScheme))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .navigationTitle("Auto-Backup")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWebDAVConfig) {
            WebDAVConfigSheet(store: store)
        }
        .alert("Set Backup Password", isPresented: $showSetPassword) {
            SecureField("Password", text: $backupPassword)
            SecureField("Confirm Password", text: $confirmPassword)
            Button("Cancel", role: .cancel) {
                backupPassword = ""
                confirmPassword = ""
                pendingEnable = false
            }
            Button("Set Password") {
                handleSetPassword()
            }
        } message: {
            Text("Your backups are encrypted with this password. Keep it safe. You'll need it to restore.\(passwordError.map { "\n\n⚠️ \($0)" } ?? "")")
        }
        .alert("Change Backup Password", isPresented: $showChangePassword) {
            SecureField("New Password", text: $backupPassword)
            SecureField("Confirm Password", text: $confirmPassword)
            Button("Cancel", role: .cancel) {
                backupPassword = ""
                confirmPassword = ""
            }
            Button("Update") {
                handleSetPassword()
            }
        } message: {
            Text("Set a new password for future backups. Existing backups still use the old password.\(passwordError.map { "\n\n⚠️ \($0)" } ?? "")")
        }
    }

    private func handleSetPassword() {
        guard !backupPassword.isEmpty else {
            passwordError = "Password cannot be empty"
            if pendingEnable {
                showSetPassword = true
            } else {
                showChangePassword = true
            }
            return
        }
        guard backupPassword == confirmPassword else {
            passwordError = "Passwords don't match"
            backupPassword = ""
            confirmPassword = ""
            if pendingEnable {
                showSetPassword = true
            } else {
                showChangePassword = true
            }
            return
        }

        authService.setBackupPassword(backupPassword)
        store.settings.hasSetBackupPassword = true

        if pendingEnable {
            store.settings.autoBackupEnabled = true
        }

        store.saveSettings()
        backupPassword = ""
        confirmPassword = ""
        passwordError = nil
        pendingEnable = false
    }

    private func destinationRow(icon: String, title: String, subtitle: String, destination: BackupDestination, color: Color) -> some View {
        Button {
            withAnimation {
                store.settings.backupDestination = destination
                store.saveSettings()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: store.settings.backupDestination == destination ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(store.settings.backupDestination == destination ? color : .secondary)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }
}
