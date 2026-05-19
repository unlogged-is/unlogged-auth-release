import SwiftUI
import AVFoundation
import PhotosUI

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
    @State private var addedToken: OTPToken?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoScanError = false

    enum AddMode: String, CaseIterable {
        case scan = "Scan QR"
        case manual = "Manual Entry"
    }

    var body: some View {
        NavigationStack {
            Group {
                if let token = addedToken {
                    tokenAddedView(token: token)
                } else {
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
                }
            }
            .navigationTitle(addedToken != nil ? "Token Added" : "Add Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if addedToken == nil {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if addedToken != nil {
                        Button("Done") { dismiss() }
                    } else if mode == .manual {
                        Button("Add") { addManualToken() }
                            .disabled(secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("No QR Code Found", isPresented: $showPhotoScanError) {
                Button("OK") {}
            } message: {
                Text("No valid otpauth:// QR code was found in the selected photo.")
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
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(Color(.systemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.top, 16)
            #else
            if AVCaptureDevice.default(for: .video) != nil {
                QRScannerView { uri in
                    handleScannedURI(uri)
                }
                .frame(height: 300)
                .clipShape(.rect(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 16)
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
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(Color(.systemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 16)
            }
            #endif

            Text("Point your camera at a QR code")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Scan from Photo", systemImage: "photo")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let uri = detectQRCode(in: image) {
                        handleScannedURI(uri)
                    } else {
                        showPhotoScanError = true
                    }
                    selectedPhoto = nil
                }
            }

            Spacer()

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

    private func tokenAddedView(token: OTPToken) -> some View {
        TokenAddedConfirmationView(token: token, iconFetcher: iconFetcher)
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
        withAnimation { addedToken = token }
    }

    private func detectQRCode(in image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] ?? []
        return features.first(where: { $0.messageString?.hasPrefix("otpauth://") == true })?.messageString
    }

    private func handleScannedURI(_ uri: String) {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = OTPAuthParser.parse(uri: trimmed) else { return }
        store.addToken(token)
        Task { await iconFetcher.fetchIcon(for: token.issuer, account: token.account) }
        withAnimation { addedToken = token }
    }
}

// MARK: - Token Added Confirmation

private struct TokenAddedConfirmationView: View {
    let token: OTPToken
    let iconFetcher: ServiceIconFetcher

    @State private var currentCode: String = ""
    @State private var progress: Double = 0
    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text(token.issuer.isEmpty ? "Unknown" : token.issuer)
                    .font(.loraTitle)

                if !token.account.isEmpty {
                    Text(token.account)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("Your verification code")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(OTPGenerator.formatCode(currentCode))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())

                if token.type == .totp {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(progressColor.opacity(0.2), lineWidth: 3)
                                .frame(width: 24, height: 24)
                            Circle()
                                .trim(from: 0, to: max(0, 1 - progress))
                                .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 24, height: 24)
                                .animation(.linear(duration: 0.5), value: progress)
                            Text("\(remainingSeconds)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(progressColor)
                        }
                        Text("seconds remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .themedSecondaryBackground()
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 24)

            Button {
                UIPasteboard.general.string = currentCode
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Label(copied ? "Copied!" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .padding(.horizontal, 24)
            .sensoryFeedback(.selection, trigger: copied)

            Text("Enter this code on the website to complete setup.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var progressColor: Color {
        if progress > 0.8 { return .red }
        if progress > 0.6 { return .orange }
        return .accent
    }

    private func startTimer() {
        updateCode()
        updateProgress()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                updateProgress()
                let newCode = OTPGenerator.generate(for: token)
                if newCode != currentCode {
                    withAnimation(.snappy(duration: 0.2)) {
                        currentCode = newCode
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCode() {
        currentCode = OTPGenerator.generate(for: token)
    }

    private func updateProgress() {
        progress = OTPGenerator.progress(for: token.period)
        remainingSeconds = Int(OTPGenerator.remainingSeconds(for: token.period))
    }
}
