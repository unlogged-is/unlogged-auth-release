import SwiftUI

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let iconFetcher: ServiceIconFetcher
    let issuer: String
    var onIconSelected: (() -> Void)?

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var loadingSlug: String?

    private var filteredIcons: [ServiceIconFetcher.SimpleIconEntry] {
        ServiceIconFetcher.searchIcons(query: searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredIcons) { entry in
                    Button {
                        selectIcon(entry)
                    } label: {
                        HStack(spacing: 12) {
                            IconPreviewCell(entry: entry, iconFetcher: iconFetcher)
                                .frame(width: 36, height: 36)

                            Text(entry.title)
                                .foregroundStyle(.primary)

                            Spacer()

                            if loadingSlug == entry.slug {
                                ProgressView()
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
            .searchable(text: $searchText, prompt: "Search services...")
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func selectIcon(_ entry: ServiceIconFetcher.SimpleIconEntry) {
        isLoading = true
        loadingSlug = entry.slug
        Task {
            let success = await iconFetcher.fetchSpecificIcon(
                slug: entry.slug,
                hex: entry.hex,
                forIssuer: issuer
            )
            isLoading = false
            loadingSlug = nil
            if success {
                onIconSelected?()
                dismiss()
            }
        }
    }
}

// MARK: - Icon Preview Cell (lazy-loads the rendered icon)

private struct IconPreviewCell: View {
    let entry: ServiceIconFetcher.SimpleIconEntry
    let iconFetcher: ServiceIconFetcher
    @State private var previewURL: URL?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let url = previewURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 8))
                    } else {
                        colorSwatch
                    }
                }
            } else {
                colorSwatch
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            // Check if already cached
            if let cached = iconFetcher.previewIconURL(for: entry.slug) {
                previewURL = cached
                return
            }
            // Fetch in background
            Task {
                previewURL = await iconFetcher.fetchPreviewIcon(slug: entry.slug, hex: entry.hex)
            }
        }
    }

    private var colorSwatch: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(hex: entry.hex))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Color hex initializer

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
