import SwiftUI

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let authService: AuthenticationService
    let store: TokenStore

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showMismatch = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Confirm Password", text: $confirmPassword)
                } footer: {
                    if showMismatch {
                        Text("Passwords don't match")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Set Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard newPassword == confirmPassword, !newPassword.isEmpty else {
                            showMismatch = true
                            return
                        }
                        authService.setPassword(newPassword)
                        store.settings.lockMethod = .password
                        store.saveSettings()
                        dismiss()
                    }
                    .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
        }
    }
}
