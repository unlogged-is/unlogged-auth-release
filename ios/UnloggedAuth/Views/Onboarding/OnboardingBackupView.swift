import SwiftUI

struct OnboardingBackupView: View {
    let store: TokenStore
    let authService: AuthenticationService
    let onContinue: () -> Void

    @State private var enableAutoBackup = false
    @State private var selectedDestination: BackupDestination = .local
    @State private var showPasswordPrompt = false
    @State private var showWebDAVConfig = false
    @State private var backupPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var webDAVConfigured = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.checkmark")
                    .font(.system(size: 56))
                    .foregroundStyle(.accent)

                Text("Backups")
                    .font(.loraTitle)

                Text("Keep your tokens safe with AES-256 encrypted auto-backups, secured by a password you choose.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.bottom, 32)
            .padding(.horizontal, 24)

            ScrollView {
                VStack(spacing: 12) {
                    // Auto-backup toggle
                    toggleRow

                    if enableAutoBackup {
                        destinationOption(
                            icon: "internaldrive.fill",
                            title: "Local Storage",
                            subtitle: "Saved to \"Unlogged Auth\" on this device",
                            destination: .local,
                            color: Color("AccentColor")
                        )

                        destinationOption(
                            icon: "icloud.fill",
                            title: "iCloud Drive",
                            subtitle: "Saved to \"Unlogged Auth\" in iCloud",
                            destination: .icloud,
                            color: .blue
                        )

                        destinationOption(
                            icon: "server.rack",
                            title: "Nextcloud / WebDAV",
                            subtitle: "Self-hosted backup server",
                            destination: .webdav,
                            color: .purple
                        )
                    }
                }
                .padding(.horizontal, 24)
                .animation(.snappy, value: enableAutoBackup)
            }

            Spacer()

            Button {
                handleContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .alert("Set Backup Password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $backupPassword)
            SecureField("Confirm Password", text: $confirmPassword)
            Button("Cancel", role: .cancel) {
                backupPassword = ""
                confirmPassword = ""
                passwordError = nil
            }
            Button("Set Password") {
                handlePasswordSubmit()
            }
        } message: {
            Text("Your backups are encrypted with this password. Keep it safe. You'll need it to restore.\(passwordError.map { "\n\n⚠️ \($0)" } ?? "")")
        }
        .sheet(isPresented: $showWebDAVConfig, onDismiss: {
            if webDAVConfigured {
                showPasswordPrompt = true
            }
        }) {
            WebDAVConfigSheet(store: store, onSave: {
                webDAVConfigured = true
            })
        }
    }

    private var toggleRow: some View {
        Button {
            withAnimation(.snappy) { enableAutoBackup.toggle() }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundStyle(enableAutoBackup ? .white : .accent)
                    .frame(width: 44, height: 44)
                    .background(enableAutoBackup ? Color.accentColor : Color.accentColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Auto-Backup")
                        .font(.loraSubheadline)
                        .foregroundStyle(.primary)
                    Text("Automatically back up your tokens daily")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: enableAutoBackup ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(enableAutoBackup ? .accent : .secondary)
                    .font(.title3)
            }
            .padding(16)
            .themedSecondaryBackground()
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(enableAutoBackup ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func destinationOption(icon: String, title: String, subtitle: String, destination: BackupDestination, color: Color) -> some View {
        Button {
            withAnimation(.snappy) { selectedDestination = destination }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(selectedDestination == destination ? .white : color)
                    .frame(width: 44, height: 44)
                    .background(selectedDestination == destination ? color : color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.loraSubheadline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: selectedDestination == destination ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedDestination == destination ? color : .secondary)
                    .font(.title3)
            }
            .padding(16)
            .themedSecondaryBackground()
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedDestination == destination ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func handleContinue() {
        if !enableAutoBackup {
            onContinue()
            return
        }

        store.settings.backupDestination = selectedDestination
        store.saveSettings()

        if selectedDestination == .webdav {
            webDAVConfigured = false
            showWebDAVConfig = true
        } else {
            passwordError = nil
            backupPassword = ""
            confirmPassword = ""
            showPasswordPrompt = true
        }
    }

    private func handlePasswordSubmit() {
        guard !backupPassword.isEmpty else {
            passwordError = "Password cannot be empty"
            showPasswordPrompt = true
            return
        }
        guard backupPassword == confirmPassword else {
            passwordError = "Passwords don't match"
            backupPassword = ""
            confirmPassword = ""
            showPasswordPrompt = true
            return
        }

        authService.setBackupPassword(backupPassword)
        store.settings.hasSetBackupPassword = true
        store.settings.autoBackupEnabled = true
        store.saveSettings()
        backupPassword = ""
        confirmPassword = ""
        passwordError = nil
        onContinue()
    }
}
