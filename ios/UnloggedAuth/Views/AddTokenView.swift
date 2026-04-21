import SwiftUI
import AVFoundation

struct AddTokenView: View {
    @Environment(\.dismiss) private var dismiss
    let store: TokenStore
    let iconFetcher: ServiceIconFetcher

    @State private var mode: AddMode = .scan
    @State private var issuer: String = ""
    @State private var account: String = ""
    @State private var secret: String = ""
    @State private var selectedType: OTPType = .totp
    @State private var selectedAlgorithm: OTPAlgorithm = .sha1
    @State private var digits: Int = 6
    @State private var period: Int = 30
    @State private var counter: UInt64 = 0
    @State private var showInvalidSecret = false
    @State private var scannedURI: String = ""
    @State private var iconLookupTask: Task<Void, Never>?
    @State private var showIconPicker = false
    @State private var iconRefreshId = UUID()

    enum AddMode: String, CaseIterable {
        case scan = "Scan QR"
        case manual = "Manual Entry"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(AddMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if mode == .scan {
                    scannerView
                } else {
                    manualEntryForm
                }
            }
            .navigationTitle("Add Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if mode == .manual {
                        Button("Add") { addManualToken() }
                            .disabled(secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Invalid Secret", isPresented: $showInvalidSecret) {
                Button("OK") {}
            } message: {
                Text("The secret key is not valid Base32. Please check and try again.")
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    iconFetcher: iconFetcher,
                    issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "custom"
                        : issuer
                ) {
                    iconRefreshId = UUID()
                }
            }
        }
    }

    @ViewBuilder
    private var scannerView: some View {
        VStack(spacing: 20) {
            #if targetEnvironment(simulator)
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Camera Preview")
                    .font(.title2.weight(.semibold))
                Text("Install this app on your device to scan QR codes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            #else
            if AVCaptureDevice.default(for: .video) != nil {
                QRScannerView { uri in
                    handleScannedURI(uri)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Camera Preview")
                        .font(.title2.weight(.semibold))
                    Text("Install this app on your device to scan QR codes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
            #endif

            VStack(spacing: 8) {
                Text("Or paste an otpauth:// URI")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("otpauth://totp/...", text: $scannedURI)
                        .font(.system(.caption, design: .monospaced))
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(10)
                        .themedSecondaryBackground()
                        .clipShape(.rect(cornerRadius: 8))

                    Button("Add") {
                        handleScannedURI(scannedURI)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                    .disabled(scannedURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var manualEntryForm: some View {
        Form {
            Section("Account Info") {
                HStack(spacing: 14) {
                    Button {
                        showIconPicker = true
                    } label: {
                        issuerIcon
                            .frame(width: 44, height: 44)
                            .id(iconRefreshId)
                    }
                    .buttonStyle(.plain)

                    TextField("Issuer (e.g. Google)", text: $issuer)
                        .textContentType(.organizationName)
                        .onChange(of: issuer) { _, newValue in
                            debouncedIconLookup(for: newValue)
                        }
                }
                TextField("Account (e.g. user@example.com)", text: $account)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
            }

            Section("Secret Key") {
                TextField("Base32 secret key", text: $secret)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
            }

            Section("Type") {
                Picker("Type", selection: $selectedType) {
                    Text("TOTP (Time-based)").tag(OTPType.totp)
                    Text("HOTP (Counter-based)").tag(OTPType.hotp)
                }
            }

            Section("Advanced") {
                Picker("Algorithm", selection: $selectedAlgorithm) {
                    ForEach(OTPAlgorithm.allCases, id: \.self) { algo in
                        Text(algo.displayName).tag(algo)
                    }
                }
                Picker("Digits", selection: $digits) {
                    Text("6").tag(6)
                    Text("7").tag(7)
                    Text("8").tag(8)
                }
                if selectedType == .totp {
                    Picker("Period", selection: $period) {
                        Text("30 seconds").tag(30)
                        Text("60 seconds").tag(60)
                        Text("90 seconds").tag(90)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var issuerIcon: some View {
        let trimmed = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let iconURL = iconFetcher.iconURL(for: trimmed) {
            AsyncImage(url: iconURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 8))
                } else {
                    issuerFallbackIcon
                }
            }
        } else {
            issuerFallbackIcon
        }
    }

    private var issuerFallbackIcon: some View {
        let trimmed = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let color: Color = {
            guard !trimmed.isEmpty else { return .secondary }
            let hash = abs(trimmed.hashValue)
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .teal, .indigo, .mint]
            return colors[hash % colors.count]
        }()
        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
            Image(systemName: "key.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func debouncedIconLookup(for name: String) {
        iconLookupTask?.cancel()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        iconLookupTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await iconFetcher.fetchIcon(for: trimmed, account: account)
        }
    }

    private func addManualToken() {
        let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard Base32.decode(cleanSecret) != nil else {
            showInvalidSecret = true
            return
        }

        let token = OTPToken(
            issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
            account: account.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: cleanSecret,
            type: selectedType,
            algorithm: selectedAlgorithm,
            digits: digits,
            period: period,
            counter: counter
        )
        store.addToken(token)
        Task { await iconFetcher.fetchIcon(for: token.issuer, account: token.account) }
        dismiss()
    }

    private func handleScannedURI(_ uri: String) {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = OTPAuthParser.parse(uri: trimmed) else { return }
        store.addToken(token)
        Task { await iconFetcher.fetchIcon(for: token.issuer, account: token.account) }
        dismiss()
    }
}
