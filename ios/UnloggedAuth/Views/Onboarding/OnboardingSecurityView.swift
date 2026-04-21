import SwiftUI

struct OnboardingSecurityView: View {
    let store: TokenStore
    let authService: AuthenticationService
    let onContinue: () -> Void

    @State private var selectedMethod: LockMethod?
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPasswordRequired = false
    @State private var showPinSetup = false
    @State private var showSelectionRequired = false

    private var defaultMethod: LockMethod? {
        authService.isBiometricsAvailable ? .biometric : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.accent)

                Text("Security")
                    .font(.loraTitle)

                Text("Your tokens are encrypted with AES-256. Choose a lock method to protect access.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 60)
            .padding(.bottom, 32)

            ScrollView {
                VStack(spacing: 12) {
                    if authService.isBiometricsAvailable {
                        securityOption(
                            icon: authService.biometryIcon,
                            title: authService.biometryName,
                            subtitle: "Quick and secure, with device passcode fallback",
                            method: .biometric,
                            color: Color("AccentColor")
                        )
                    } else {
                        securityOption(
                            icon: "lock.rectangle",
                            title: "Device Passcode",
                            subtitle: "Use your device passcode to unlock",
                            method: .devicePasscode,
                            color: Color("AccentColor")
                        )
                    }

                    securityOption(
                        icon: "circle.grid.3x3.fill",
                        title: "PIN",
                        subtitle: "Encryption key tied to your PIN",
                        method: .pin,
                        color: Color("AccentColor")
                    )

                    securityOption(
                        icon: "key.fill",
                        title: "Password",
                        subtitle: "Encryption key tied to your password",
                        method: .password,
                        color: Color("AccentColor")
                    )

                    securityOption(
                        icon: "lock.open",
                        title: "No Lock",
                        subtitle: "Open access — not recommended",
                        method: .none,
                        color: .secondary
                    )

                    if selectedMethod == .password {
                        passwordFields
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                applySecurity()
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
            .disabled(!canContinue)
        }
        .sheet(isPresented: $showPinSetup) {
            NavigationStack {
                PinSetupView { pin in
                    authService.setPin(pin)
                    store.settings.lockMethod = .pin
                    store.saveSettings()
                    showPinSetup = false
                    onContinue()
                } onCancel: {
                    showPinSetup = false
                }
                .navigationTitle("Set PIN")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showPinSetup = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .alert("Select a Security Method", isPresented: $showSelectionRequired) {
            Button("OK") {}
        } message: {
            Text("Please choose how you'd like to protect your tokens before continuing.")
        }
        .onAppear {
            if selectedMethod == nil {
                selectedMethod = defaultMethod
            }
        }
    }

    private var canContinue: Bool {
        guard let method = selectedMethod else { return true } // allow tap so we can show alert
        switch method {
        case .none, .biometric, .devicePasscode, .pin:
            return true
        case .password:
            return !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
        }
    }

    @ViewBuilder
    private var passwordFields: some View {
        VStack(spacing: 12) {
            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .padding()
                .themedSecondaryBackground()
                .clipShape(.rect(cornerRadius: 12))

            SecureField("Confirm password", text: $confirmPassword)
                .padding()
                .themedSecondaryBackground()
                .clipShape(.rect(cornerRadius: 12))

            if !password.isEmpty && !confirmPassword.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(password == confirmPassword ? "Passwords match" : "Passwords don't match")
                }
                .font(.caption)
                .foregroundStyle(password == confirmPassword ? .green : .red)
                .animation(.default, value: password == confirmPassword)
            }

            if showPasswordRequired {
                Text("Please enter a password")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func securityOption(icon: String, title: String, subtitle: String, method: LockMethod, color: Color) -> some View {
        Button {
            withAnimation(.snappy) { selectedMethod = method }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(selectedMethod == method ? .white : color)
                    .frame(width: 44, height: 44)
                    .background(selectedMethod == method ? color : color.opacity(0.12))
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

                Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedMethod == method ? color : .secondary)
                    .font(.title3)
            }
            .padding(16)
            .themedSecondaryBackground()
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedMethod == method ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func applySecurity() {
        showPasswordRequired = false

        guard let selectedMethod else {
            showSelectionRequired = true
            return
        }

        switch selectedMethod {
        case .biometric:
            Task {
                if await authService.authenticateWithBiometrics() {
                    store.settings.lockMethod = .biometric
                    store.saveSettings()
                    onContinue()
                }
            }
        case .devicePasscode:
            Task {
                if await authService.authenticateWithDevicePasscode() {
                    store.settings.lockMethod = .devicePasscode
                    store.saveSettings()
                    onContinue()
                }
            }
        case .pin:
            showPinSetup = true
        case .password:
            guard !password.isEmpty else {
                showPasswordRequired = true
                return
            }
            guard password == confirmPassword else {
                return
            }
            authService.setPassword(password)
            store.settings.lockMethod = .password
            store.saveSettings()
            onContinue()
        case .none:
            store.settings.lockMethod = .none
            store.saveSettings()
            onContinue()
        }
    }
}

