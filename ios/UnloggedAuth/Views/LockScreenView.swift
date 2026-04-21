import SwiftUI

struct LockScreenView: View {
    let authService: AuthenticationService
    let lockMethod: LockMethod
    @Environment(\.scenePhase) private var scenePhase
    @State private var password: String = ""
    @State private var showError: Bool = false
    @State private var shakeOffset: CGFloat = 0
    @State private var biometricFailed: Bool = false
    @State private var authInProgress: Bool = false
    @State private var pinError: Bool = false
    @State private var pinEntryId: UUID = UUID()
    @State private var lockoutTimer: Timer?
    @State private var lockoutSeconds: Int = 0

    var body: some View {
        if lockMethod == .pin {
            pinLockLayout
        } else {
            defaultLockLayout
        }
    }

    private var pinLockLayout: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 13))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

            Text("unlogged Auth")
                .font(.loraHeadline)

            if lockoutSeconds > 0 {
                lockoutBanner
            }

            Spacer(minLength: 12)

            PinEntryView(
                pinLength: authService.storedPinLength(),
                onComplete: { attemptPinUnlock($0) },
                showError: pinError,
                title: "Enter PIN"
            )
            .id(pinEntryId)
            .allowsHitTesting(lockoutSeconds == 0)
            .opacity(lockoutSeconds > 0 ? 0.4 : 1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground()
        .onAppear { startLockoutTimer() }
        .onDisappear { stopLockoutTimer() }
        .onChange(of: authService.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                pinError = false
                pinEntryId = UUID()
            }
        }
    }

    private var defaultLockLayout: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(.rect(cornerRadius: 18))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            Text("unlogged Auth")
                .font(.loraTitle)

            Text("Locked")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 16) {
                if lockMethod == .biometric && biometricFailed {
                    Button {
                        retryBiometric()
                    } label: {
                        Label("Unlock", systemImage: authService.biometryIcon)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                }

                if lockMethod == .devicePasscode && biometricFailed {
                    Button {
                        retryDevicePasscode()
                    } label: {
                        Label("Unlock", systemImage: "lock.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                }

                if lockMethod == .password {
                    passwordEntrySection
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground()
        .onAppear {
            if scenePhase == .active && !authService.isUnlocked {
                if lockMethod == .biometric {
                    triggerBiometric()
                } else if lockMethod == .devicePasscode {
                    triggerDevicePasscode()
                }
            }
        }
        .onChange(of: authService.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                biometricFailed = false
                password = ""
                showError = false
                pinError = false
                pinEntryId = UUID()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !biometricFailed && !authService.isUnlocked {
                if lockMethod == .biometric {
                    triggerBiometric()
                } else if lockMethod == .devicePasscode {
                    triggerDevicePasscode()
                }
            }
        }
    }

    private var passwordEntrySection: some View {
        VStack(spacing: 16) {
            if lockoutSeconds > 0 {
                lockoutBanner
            }

            SecureField("Enter password", text: $password)
                .textContentType(.password)
                .padding()
                .themedSecondaryBackground()
                .clipShape(.rect(cornerRadius: 12))
                .offset(x: shakeOffset)
                .onSubmit { attemptPasswordUnlock() }
                .disabled(lockoutSeconds > 0)

            Button {
                attemptPasswordUnlock()
            } label: {
                Text("Unlock")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .disabled(password.isEmpty || lockoutSeconds > 0)
        }
        .padding(.horizontal, 40)
        .onAppear { startLockoutTimer() }
        .onDisappear { stopLockoutTimer() }
    }

    private var lockoutBanner: some View {
        VStack(spacing: 4) {
            Text("Too many failed attempts")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.red)
            Text("Try again in \(lockoutSeconds)s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func startLockoutTimer() {
        lockoutSeconds = authService.lockoutRemainingSeconds
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                lockoutSeconds = authService.lockoutRemainingSeconds
                if lockoutSeconds == 0 {
                    stopLockoutTimer()
                }
            }
        }
    }

    private func stopLockoutTimer() {
        lockoutTimer?.invalidate()
        lockoutTimer = nil
    }

    private func triggerBiometric() {
        guard !authInProgress else { return }
        authInProgress = true
        Task {
            let success = await authService.authenticateWithBiometrics()
            authInProgress = false
            if !success {
                biometricFailed = true
            }
        }
    }

    private func retryBiometric() {
        biometricFailed = false
        triggerBiometric()
    }

    private func triggerDevicePasscode() {
        guard !authInProgress else { return }
        authInProgress = true
        Task {
            let success = await authService.authenticateWithDevicePasscode()
            authInProgress = false
            if !success {
                biometricFailed = true
            }
        }
    }

    private func retryDevicePasscode() {
        biometricFailed = false
        triggerDevicePasscode()
    }

    private func attemptPinUnlock(_ pin: String) {
        if authService.authenticateWithPin(pin) {
            pinError = false
        } else {
            pinError = true
            // Reset the error after animation completes so it can trigger again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pinError = false
                pinEntryId = UUID()
            }
        }
    }

    private func attemptPasswordUnlock() {
        if authService.authenticateWithPassword(password) {
            password = ""
        } else {
            showError = true
            password = ""
            shakeAndReset()
        }
    }

    private func shakeAndReset() {
        withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            shakeOffset = 0
        }
    }
}
