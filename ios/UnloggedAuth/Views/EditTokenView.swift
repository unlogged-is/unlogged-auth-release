import SwiftUI
import CoreImage.CIFilterBuiltins

struct EditTokenView: View {
    @Environment(\.dismiss) private var dismiss
    let store: TokenStore
    let authService: AuthenticationService
    let token: OTPToken
    let iconFetcher: ServiceIconFetcher

    @State private var issuer: String
    @State private var account: String
    @State private var iconSymbol: String
    @State private var iconColor: String
    @State private var showIconPicker = false
    @State private var iconRefreshId = UUID()

    @State private var isSecretRevealed = false
    @State private var showSecretCopied = false
    @State private var showPinAuth = false
    @State private var showPasswordAuth = false
    @State private var authPasswordInput = ""
    @State private var authPasswordError = false
    @State private var authShakeOffset: CGFloat = 0

    private let availableSymbols = [
        "key.fill", "lock.fill", "shield.fill", "globe", "envelope.fill",
        "creditcard.fill", "building.2.fill", "cart.fill", "gamecontroller.fill",
        "cloud.fill", "server.rack", "desktopcomputer", "iphone", "laptopcomputer",
        "bitcoinsign.circle.fill", "dollarsign.circle.fill", "heart.fill",
        "star.fill", "bolt.fill", "person.fill", "doc.fill", "folder.fill"
    ]

    private let availableColors = [
        ("accent", "Accent"), ("red", "Red"), ("orange", "Orange"),
        ("yellow", "Yellow"), ("green", "Green"), ("blue", "Blue"),
        ("purple", "Purple"), ("pink", "Pink"), ("teal", "Teal")
    ]

    init(store: TokenStore, authService: AuthenticationService, token: OTPToken, iconFetcher: ServiceIconFetcher) {
        self.store = store
        self.authService = authService
        self.token = token
        self.iconFetcher = iconFetcher
        _issuer = State(initialValue: token.issuer)
        _account = State(initialValue: token.account)
        _iconSymbol = State(initialValue: token.iconSymbol ?? "key.fill")
        _iconColor = State(initialValue: token.iconColor ?? "accent")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Info") {
                    TextField("Issuer", text: $issuer)
                    TextField("Account", text: $account)
                }

                tokenDetailsSection

                Section("Service Icon") {
                    HStack(spacing: 14) {
                        serviceIconPreview
                            .frame(width: 44, height: 44)
                            .id(iconRefreshId)

                        Button("Choose Service Icon...") {
                            showIconPicker = true
                        }
                    }
                }

                Section("Fallback Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                        ForEach(availableSymbols, id: \.self) { symbol in
                            Button {
                                iconSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18))
                                    .foregroundStyle(iconSymbol == symbol ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(iconSymbol == symbol ? Color.accentColor : Color(.tertiarySystemBackground))
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Fallback Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                        ForEach(availableColors, id: \.0) { color in
                            Button {
                                iconColor = color.0
                            } label: {
                                Circle()
                                    .fill(colorForName(color.0))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if iconColor == color.0 {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Edit Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    iconFetcher: iconFetcher,
                    issuer: issuer.isEmpty ? token.issuer : issuer
                ) {
                    iconRefreshId = UUID()
                }
            }
            .sheet(isPresented: $showPinAuth) {
                pinAuthSheet
            }
            .sheet(isPresented: $showPasswordAuth) {
                passwordAuthSheet
            }
        }
    }

    @ViewBuilder
    private var tokenDetailsSection: some View {
        Section {
            LabeledContent("Type", value: token.type == .totp ? "TOTP" : "HOTP")
            LabeledContent("Algorithm", value: token.algorithm.displayName)
            LabeledContent("Digits", value: "\(token.digits)")
            if token.type == .totp {
                LabeledContent("Period", value: "\(token.period)s")
            }

            if isSecretRevealed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Secret Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(token.secret)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)

                if let qr = qrCodeImage {
                    VStack(spacing: 8) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(.rect(cornerRadius: 8))
                        Text("Scan to add this token to another authenticator")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                Button {
                    UIPasteboard.general.string = token.secret
                    withAnimation { showSecretCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showSecretCopied = false }
                    }
                } label: {
                    Label(showSecretCopied ? "Copied!" : "Copy Secret", systemImage: showSecretCopied ? "checkmark" : "doc.on.doc")
                }

                Button(role: .destructive) {
                    withAnimation { isSecretRevealed = false }
                } label: {
                    Label("Hide Secret", systemImage: "eye.slash")
                }
            } else {
                Button {
                    requestRevealSecret()
                } label: {
                    Label("Reveal Secret Key", systemImage: "eye")
                }
            }
        } header: {
            Text("Token Details")
        } footer: {
            if isSecretRevealed {
                Text("Anyone with this secret can generate codes for this account. Do not share it.")
            }
        }
    }

    private var otpAuthURI: String {
        let typeStr = token.type == .totp ? "totp" : "hotp"
        let issuerEnc = token.issuer.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token.issuer
        let accountEnc = token.account.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token.account
        let label = issuerEnc.isEmpty ? accountEnc : "\(issuerEnc):\(accountEnc)"

        var params = [
            "secret=\(token.secret)",
            "issuer=\(issuerEnc)",
            "algorithm=\(token.algorithm.rawValue.uppercased())",
            "digits=\(token.digits)"
        ]
        if token.type == .totp {
            params.append("period=\(token.period)")
        } else {
            params.append("counter=\(token.counter)")
        }
        return "otpauth://\(typeStr)/\(label)?\(params.joined(separator: "&"))"
    }

    private var qrCodeImage: UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(otpAuthURI.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private var pinAuthSheet: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Verify Identity")
                .font(.loraTitle)
            Text("Enter your PIN to reveal the secret key")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PinEntryView(
                pinLength: authService.storedPinLength(),
                onComplete: { pin in
                    Task {
                        let success = await authService.authenticateWithPin(pin)
                        if success {
                            showPinAuth = false
                            isSecretRevealed = true
                        } else {
                            authPasswordError = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                authPasswordError = false
                            }
                        }
                    }
                },
                showError: authPasswordError,
                title: ""
            )
            Spacer()
            Button("Cancel") { showPinAuth = false }
                .padding(.bottom, 20)
        }
        .padding()
        .themedBackground()
    }

    private var passwordAuthSheet: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Verify Identity")
                .font(.loraTitle)
            Text("Enter your password to reveal the secret key")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Password", text: $authPasswordInput)
                .textContentType(.password)
                .padding()
                .themedSecondaryBackground()
                .clipShape(.rect(cornerRadius: 12))
                .offset(x: authShakeOffset)
                .onSubmit { attemptPasswordAuth() }

            Button {
                attemptPasswordAuth()
            } label: {
                Text("Verify")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .disabled(authPasswordInput.isEmpty)

            Spacer()
            Button("Cancel") {
                authPasswordInput = ""
                showPasswordAuth = false
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .themedBackground()
    }

    private func requestRevealSecret() {
        switch store.settings.lockMethod {
        case .none:
            withAnimation { isSecretRevealed = true }
        case .biometric:
            Task {
                if await authService.authenticateWithBiometrics() {
                    isSecretRevealed = true
                }
            }
        case .devicePasscode:
            Task {
                if await authService.authenticateWithDevicePasscode() {
                    isSecretRevealed = true
                }
            }
        case .pin:
            authPasswordError = false
            showPinAuth = true
        case .password:
            authPasswordInput = ""
            showPasswordAuth = true
        }
    }

    private func attemptPasswordAuth() {
        Task {
            let success = await authService.authenticateWithPassword(authPasswordInput)
            if success {
                authPasswordInput = ""
                showPasswordAuth = false
                isSecretRevealed = true
            } else {
                authPasswordInput = ""
                withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                    authShakeOffset = 10
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    authShakeOffset = 0
                }
            }
        }
    }

    @ViewBuilder
    private var serviceIconPreview: some View {
        let name = issuer.isEmpty ? token.issuer : issuer
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let iconURL = iconFetcher.iconURL(for: trimmed) {
            AsyncImage(url: iconURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    fallbackPreviewIcon
                }
            }
        } else {
            fallbackPreviewIcon
        }
    }

    private var fallbackPreviewIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(colorForName(iconColor).opacity(0.15))
            Image(systemName: iconSymbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(colorForName(iconColor))
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        default: return .accentColor
        }
    }

    private func saveChanges() {
        let newIssuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldIssuer = token.issuer

        // Migrate cached icon if issuer name changed
        if !newIssuer.isEmpty && newIssuer != oldIssuer {
            iconFetcher.migrateIcon(fromIssuer: oldIssuer, toIssuer: newIssuer)
        }

        var updated = token
        updated.issuer = newIssuer
        updated.account = account
        updated.iconSymbol = iconSymbol
        updated.iconColor = iconColor
        store.updateToken(updated)
        dismiss()
    }
}
