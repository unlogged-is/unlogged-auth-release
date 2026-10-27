import SwiftUI

struct TokensListView: View {
    let store: TokenStore
    let authService: AuthenticationService
    let iconFetcher: ServiceIconFetcher
    @State private var searchText: String = ""
    @State private var showAddToken: Bool = false
    @State private var editingToken: OTPToken?
    @State private var tokenToMove: OTPToken?
    @State private var tokenToDelete: OTPToken?
    @State private var copiedTokenId: UUID?
    @State private var showDuoSearch: Bool = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // iPhone Duo optimizations
    @State private var deviceCapabilities = DeviceCapabilities.shared

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular || deviceCapabilities.isInnerDisplay
    }

    private var isCompactWidth: Bool {
        !isRegularWidth
    }
    
    private var shouldUseInlineSearch: Bool {
        // Use inline search on iPhone Duo (both displays) or iPad
        let isDuo = deviceCapabilities.isPhoneDuo
        let isRegular = horizontalSizeClass == .regular
        print("🔍 Debug - isDuo: \(isDuo), isRegular: \(isRegular), shouldUseInline: \(isDuo || (isRegular && !isDuo))")
        return isDuo || (isRegular && !isDuo)
    }

    private var filteredTokens: [OTPToken] {
        let sorted: [OTPToken]
        switch store.settings.tokenSortOrder {
        case .name:
            sorted = store.tokens.sorted { $0.issuer.localizedCaseInsensitiveCompare($1.issuer) == .orderedAscending }
        case .recentlyAdded:
            sorted = store.tokens.sorted { $0.createdAt > $1.createdAt }
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.issuer.localizedStandardContains(searchText) ||
            $0.account.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.tokens.isEmpty {
                    ContentUnavailableView {
                        Label("No Tokens", systemImage: "key.slash")
                    } description: {
                        Text("Add your first token.")
                    } actions: {
                        Button("Add Token") { showAddToken = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.accent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: deviceCapabilities.optimizedGridColumns(),
                            spacing: deviceCapabilities.isInnerDisplay ? 16 : 12
                        ) {
                            ForEach(filteredTokens) { token in
                                TokenCardView(
                                    token: token,
                                    iconFetcher: iconFetcher,
                                    isCopied: copiedTokenId == token.id,
                                    onCopy: { copyCode(for: token) },
                                    onIncrement: {
                                        if token.type == .hotp {
                                            store.incrementCounter(for: token.id)
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button {
                                        copyCode(for: token)
                                    } label: {
                                        Label("Copy Code", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        editingToken = token
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button {
                                        tokenToMove = token
                                    } label: {
                                        Label("Move to Group", systemImage: "folder")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        tokenToDelete = token
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .deviceAdaptivePadding()
                        .padding(.top, 8)
                    }


                }
            }
            .themedBackground()
            .navigationTitle("Tokens")
            .if(!shouldUseInlineSearch) { view in
                view
                    .searchable(text: $searchText, prompt: "Search tokens")
                    .searchFocused($isSearchFocused)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort By", selection: Binding(
                            get: { store.settings.tokenSortOrder },
                            set: {
                                store.settings.tokenSortOrder = $0
                                store.saveSettings()
                            }
                        )) {
                            Label("Name", systemImage: "textformat.abc")
                                .tag(TokenSortOrder.name)
                            Label("Recently Added", systemImage: "clock")
                                .tag(TokenSortOrder.recentlyAdded)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddToken = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                    }
                }
                
                if shouldUseInlineSearch {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.snappy(duration: 0.3)) {
                                showDuoSearch.toggle()
                            }
                            if showDuoSearch {
                                isSearchFocused = true
                            } else {
                                searchText = ""
                                isSearchFocused = false
                            }
                        } label: {
                            Image(systemName: showDuoSearch ? "xmark" : "magnifyingglass")
                                .font(.subheadline)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if shouldUseInlineSearch && showDuoSearch {
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.tertiary)
                                .font(.body)
                            
                            TextField("Search tokens", text: $searchText)
                                .focused($isSearchFocused)
                                .textFieldStyle(.plain)
                                .font(.body)
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                        .font(.body)
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                        }
                        .frame(maxWidth: 400)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                }
            }
            .onAppear {
                deviceCapabilities.updateDetection()
                if store.settings.focusSearchOnLaunch {
                    isSearchFocused = true
                }
            }
            .sheet(isPresented: $showAddToken) {
                AddTokenView(store: store, iconFetcher: iconFetcher)
            }
            .sheet(item: $editingToken) { token in
                EditTokenView(store: store, authService: authService, token: token, iconFetcher: iconFetcher)
            }
            .sheet(item: $tokenToMove) { token in
                MoveToGroupSheet(store: store, token: token)
            }
            .alert(
                "Delete Token?",
                isPresented: Binding(
                    get: { tokenToDelete != nil },
                    set: { if !$0 { tokenToDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { tokenToDelete = nil }
                if store.settings.trashRetention != .off {
                    Button("Move to Trash", role: .destructive) {
                        if let token = tokenToDelete {
                            withAnimation { store.trashToken(id: token.id) }
                        }
                        tokenToDelete = nil
                    }
                }
                Button("Delete Permanently", role: .destructive) {
                    if let token = tokenToDelete {
                        withAnimation { store.deleteToken(id: token.id) }
                    }
                    tokenToDelete = nil
                }
            } message: {
                if let token = tokenToDelete {
                    if store.settings.trashRetention != .off {
                        Text("\"\(token.issuer)\" will be moved to trash and automatically deleted after \(store.settings.trashRetention.displayName.lowercased()).")
                    } else {
                        Text("\"\(token.issuer)\" will be permanently deleted. This cannot be undone.")
                    }
                }
            }
        }
    }

    private func copyCode(for token: OTPToken) {
        let code = OTPGenerator.generate(for: token)
        UIPasteboard.general.string = code
        withAnimation(.spring(duration: 0.3)) {
            copiedTokenId = token.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copiedTokenId = nil }
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
