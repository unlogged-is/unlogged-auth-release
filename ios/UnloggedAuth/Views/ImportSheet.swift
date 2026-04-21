import SwiftUI
import UniformTypeIdentifiers

struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: TokenStore
    let iconFetcher: ServiceIconFetcher

    @State private var showFilePicker = false
    @State private var showURIInput = false
    @State private var uriText = ""
    @State private var importedCount = 0
    @State private var showImportResult = false
    @State private var showImportFailed = false
    @State private var selectedSource: ImportSource?

    var body: some View {
        NavigationStack {
            List {
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

                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.rawValue)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(source.instructions)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json, .plainText, .data], allowsMultipleSelection: false) { result in
            handleFileImport(result)
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            Text("\(importedCount) token\(importedCount == 1 ? "" : "s") imported.")
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
