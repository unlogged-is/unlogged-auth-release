import SwiftUI

struct MoveToGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: TokenStore
    let token: OTPToken
    @State private var showNewGroupAlert: Bool = false
    @State private var newGroupName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        moveToGroup(nil)
                    } label: {
                        HStack {
                            Image(systemName: "tray.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            Text("No Group")
                                .foregroundStyle(.primary)
                            Spacer()
                            if token.groupId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }

                    ForEach(store.groups) { group in
                        Button {
                            moveToGroup(group.id)
                        } label: {
                            HStack {
                                Image(systemName: group.iconSymbol)
                                    .foregroundStyle(.accent)
                                    .frame(width: 28)
                                Text(group.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if token.groupId == group.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showNewGroupAlert = true
                    } label: {
                        Label("Create New Group", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Move to Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Group", isPresented: $showNewGroupAlert) {
                TextField("Group name", text: $newGroupName)
                Button("Cancel", role: .cancel) { newGroupName = "" }
                Button("Create") {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let group = TokenGroup(name: trimmed)
                    store.addGroup(group)
                    moveToGroup(group.id)
                    newGroupName = ""
                }
            }
        }
    }

    private func moveToGroup(_ groupId: UUID?) {
        var updated = token
        updated.groupId = groupId
        store.updateToken(updated)
        dismiss()
    }
}
