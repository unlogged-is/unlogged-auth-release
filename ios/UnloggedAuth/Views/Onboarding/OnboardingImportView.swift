import SwiftUI
import UniformTypeIdentifiers

struct OnboardingImportView: View {
    let store: TokenStore
    let iconFetcher: ServiceIconFetcher
    let onContinue: () -> Void

    @State private var showFilePicker = false
    @State private var showURIInput = false
    @State private var uriText = ""
    @State private var importedCount = 0
    @State private var showImportResult = false
    @State private var showImportFailed = false
    @State private var selectedSource: ImportSource?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.accent)

                Text("Import Tokens")
                    .font(.loraTitle)

                Text("Already using an authenticator?\nImport your existing tokens.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.bottom, 32)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ImportSource.allCases) { source in
                        Button {
                            selectedSource = source
                            if source == .otpauthURI {
                                showURIInput = true
                            } else {
                                showFilePicker = true
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: source.icon)
                                    .font(.title3)
                                    .foregroundStyle(.accent)
                                    .frame(width: 36, height: 36)

                                Text(source.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .themedSecondaryBackground()
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                onContinue()
            } label: {
                Text(store.tokens.isEmpty ? "Skip" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json, .plainText, .data], allowsMultipleSelection: false) { result in
            handleFileImport(result)
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            Text("\(importedCount) token\(importedCount == 1 ? "" : "s") imported successfully.")
        }
        .alert("Import Failed", isPresented: $showImportFailed) {
            Button("OK") {}
        } message: {
            Text("No tokens found in the selected file. Make sure you're using an unencrypted export file from your authenticator app.")
        }
        .sheet(isPresented: $showURIInput) {
            URIInputSheet(uriText: $uriText) { text in
                let tokens = ImportService.parseURIs(text)
                store.importTokens(tokens)
                importedCount = tokens.count
                showImportResult = true
                for token in tokens {
                    Task { await iconFetcher.fetchIcon(for: token.issuer, account: token.account) }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let urls = try? result.get(), let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }

        let tokens = ImportService.smartImport(data)

        if tokens.isEmpty {
            showImportFailed = true
            return
        }

        store.importTokens(tokens)
        importedCount = tokens.count
        showImportResult = true
        for token in tokens {
            Task { await iconFetcher.fetchIcon(for: token.issuer, account: token.account) }
        }
    }
}

struct URIInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var uriText: String
    let onImport: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste one or more otpauth:// URIs, one per line.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $uriText)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .themedSecondaryBackground()
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Paste URIs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(uriText)
                        dismiss()
                    }
                    .disabled(uriText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
