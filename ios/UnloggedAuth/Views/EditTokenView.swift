import SwiftUI

struct EditTokenView: View {
    @Environment(\.dismiss) private var dismiss
    let store: TokenStore
    let token: OTPToken
    let iconFetcher: ServiceIconFetcher

    @State private var issuer: String
    @State private var account: String
    @State private var iconSymbol: String
    @State private var iconColor: String
    @State private var showIconPicker = false
    @State private var iconRefreshId = UUID()

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

    init(store: TokenStore, token: OTPToken, iconFetcher: ServiceIconFetcher) {
        self.store = store
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

                Section("Token Details") {
                    LabeledContent("Type", value: token.type == .totp ? "TOTP" : "HOTP")
                    LabeledContent("Algorithm", value: token.algorithm.displayName)
                    LabeledContent("Digits", value: "\(token.digits)")
                    if token.type == .totp {
                        LabeledContent("Period", value: "\(token.period)s")
                    }
                }

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
