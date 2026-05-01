import SwiftUI

struct GroupsView: View {
    let store: TokenStore
    let iconFetcher: ServiceIconFetcher
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showAddGroup = false
    @State private var editingGroup: TokenGroup?
    @State private var newGroupName = ""
    @State private var selectedGroup: TokenGroup?
    @State private var groupToDelete: TokenGroup?

    var body: some View {
        NavigationStack {
            Group {
                if store.groups.isEmpty {
                    ContentUnavailableView {
                        Label("No Groups", systemImage: "folder")
                    } description: {
                        Text("Create groups to organize your tokens.")
                    } actions: {
                        Button("Create Group") { showAddGroup = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.accent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12)], spacing: 12) {
                            ForEach(store.groups) { group in
                                groupCard(group)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddGroup = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                    }
                }
            }
            .alert("New Group", isPresented: $showAddGroup) {
                TextField("Group name", text: $newGroupName)
                Button("Cancel", role: .cancel) { newGroupName = "" }
                Button("Create") {
                    guard !newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    store.addGroup(TokenGroup(name: newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)))
                    newGroupName = ""
                }
            }
            .alert("Rename Group", isPresented: Binding(
                get: { editingGroup != nil },
                set: { if !$0 { editingGroup = nil } }
            )) {
                TextField("Group name", text: $newGroupName)
                Button("Cancel", role: .cancel) {
                    editingGroup = nil
                    newGroupName = ""
                }
                Button("Save") {
                    if var group = editingGroup {
                        group.name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.updateGroup(group)
                    }
                    editingGroup = nil
                    newGroupName = ""
                }
            }
            .alert("Delete Group?", isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { groupToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let group = groupToDelete {
                        withAnimation { store.deleteGroup(id: group.id) }
                    }
                    groupToDelete = nil
                }
            } message: {
                Text("Tokens in this group will be moved back to the main list.")
            }
            .navigationDestination(item: $selectedGroup) { group in
                GroupDetailView(store: store, group: group, iconFetcher: iconFetcher)
            }
        }
    }

    private func groupCard(_ group: TokenGroup) -> some View {
        Button {
            selectedGroup = group
        } label: {
            HStack(spacing: 14) {
                Image(systemName: group.iconSymbol)
                    .font(.title3)
                    .foregroundStyle(.accent)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.loraTokenName)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(store.tokenCount(for: group.id)) tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .themedSecondaryBackground()
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingGroup = group
                newGroupName = group.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                groupToDelete = group
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct GroupDetailView: View {
    let store: TokenStore
    let group: TokenGroup
    let iconFetcher: ServiceIconFetcher
    @State private var copiedTokenId: UUID?

    private var groupTokens: [OTPToken] {
        store.tokensInGroup(group.id)
    }

    var body: some View {
        Group {
            if groupTokens.isEmpty {
                ContentUnavailableView {
                    Label("No Tokens", systemImage: "key.slash")
                } description: {
                    Text("Move tokens to this group from the Tokens tab.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12)], spacing: 12) {
                        ForEach(groupTokens) { token in
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
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .themedBackground()
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
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
