import SwiftUI

struct TrashView: View {
    let store: TokenStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEmptyConfirm = false
    @State private var tokenToRestore: TrashedToken?
    @State private var tokenToPermanentlyDelete: TrashedToken?

    var body: some View {
        Group {
            if store.trashedTokens.isEmpty {
                ContentUnavailableView {
                    Label("Trash is Empty", systemImage: "trash")
                } description: {
                    Text("Deleted tokens will appear here.")
                }
            } else {
                List {
                    ForEach(store.trashedTokens.sorted(by: { $0.deletedAt > $1.deletedAt })) { item in
                        trashedTokenRow(item)
                    }
                }
                .listRowBackground(Color.themedSecondary(for: colorScheme))
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("Trash")
        .toolbar {
            if !store.trashedTokens.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Empty Trash", role: .destructive) {
                        showEmptyConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .alert("Empty Trash?", isPresented: $showEmptyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                withAnimation { store.emptyTrash() }
            }
        } message: {
            Text("All \(store.trashedTokens.count) token\(store.trashedTokens.count == 1 ? "" : "s") will be permanently deleted. This cannot be undone.")
        }
        .alert("Restore Token?", isPresented: Binding(
            get: { tokenToRestore != nil },
            set: { if !$0 { tokenToRestore = nil } }
        )) {
            Button("Cancel", role: .cancel) { tokenToRestore = nil }
            Button("Restore") {
                if let item = tokenToRestore {
                    withAnimation { store.restoreToken(id: item.token.id) }
                }
                tokenToRestore = nil
            }
        } message: {
            if let item = tokenToRestore {
                Text("\"\(item.token.issuer)\" will be restored to your tokens list.")
            }
        }
        .alert("Delete Permanently?", isPresented: Binding(
            get: { tokenToPermanentlyDelete != nil },
            set: { if !$0 { tokenToPermanentlyDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { tokenToPermanentlyDelete = nil }
            Button("Delete", role: .destructive) {
                if let item = tokenToPermanentlyDelete {
                    withAnimation { store.permanentlyDeleteTrashedToken(id: item.token.id) }
                }
                tokenToPermanentlyDelete = nil
            }
        } message: {
            if let item = tokenToPermanentlyDelete {
                Text("\"\(item.token.issuer)\" will be permanently deleted. This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func trashedTokenRow(_ item: TrashedToken) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.token.issuer)
                    .font(.headline)
                if !item.token.account.isEmpty {
                    Text(item.token.account)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(timeRemainingText(for: item))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .swipeActions(edge: .leading) {
            Button {
                tokenToRestore = item
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.accent)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                tokenToPermanentlyDelete = item
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
        .contextMenu {
            Button {
                tokenToRestore = item
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            Divider()
            Button(role: .destructive) {
                tokenToPermanentlyDelete = item
            } label: {
                Label("Delete Permanently", systemImage: "trash.fill")
            }
        }
    }

    private func timeRemainingText(for item: TrashedToken) -> String {
        guard let retentionDays = store.settings.trashRetention.days else {
            return "Deleted \(item.daysInTrash) day\(item.daysInTrash == 1 ? "" : "s") ago"
        }
        let remaining = retentionDays - item.daysInTrash
        if remaining <= 0 {
            return "Expires soon"
        }
        return "Deleted \(item.daysInTrash) day\(item.daysInTrash == 1 ? "" : "s") ago · \(remaining) day\(remaining == 1 ? "" : "s") left"
    }
}
