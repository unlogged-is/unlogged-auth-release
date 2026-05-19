import Foundation

@Observable
@MainActor
class TokenStore {
    var tokens: [OTPToken] = []
    var groups: [TokenGroup] = []
    var settings: AppSettingsData = AppSettingsData()
    var trashedTokens: [TrashedToken] = []
    var onTokensChanged: (() -> Void)?

    private let tokensFileURL: URL
    private let groupsFileURL: URL
    private let settingsFileURL: URL
    private let trashFileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        tokensFileURL = appSupport.appendingPathComponent("tokens.encrypted")
        groupsFileURL = appSupport.appendingPathComponent("groups.json")
        settingsFileURL = appSupport.appendingPathComponent("settings.json")
        trashFileURL = appSupport.appendingPathComponent("trash.encrypted")

        migrateFromDocuments()
        loadAll()
    }

    private func migrateFromDocuments() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filesToMigrate = ["tokens.encrypted", "groups.json", "settings.json", "trash.encrypted"]
        for filename in filesToMigrate {
            let oldURL = docs.appendingPathComponent(filename)
            let newURL: URL
            switch filename {
            case "tokens.encrypted": newURL = tokensFileURL
            case "groups.json": newURL = groupsFileURL
            case "settings.json": newURL = settingsFileURL
            case "trash.encrypted": newURL = trashFileURL
            default: continue
            }
            if FileManager.default.fileExists(atPath: oldURL.path) && !FileManager.default.fileExists(atPath: newURL.path) {
                try? FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        }
    }

    func loadAll() {
        loadTokens()
        loadGroups()
        loadSettings()
        loadTrash()
        cleanupExpiredTrash()
    }

    private func loadTokens() {
        guard FileManager.default.fileExists(atPath: tokensFileURL.path) else { return }
        do {
            let encrypted = try Data(contentsOf: tokensFileURL)
            let decrypted = try EncryptionService.decrypt(encrypted)
            tokens = try JSONDecoder().decode([OTPToken].self, from: decrypted)
        } catch {
            if let raw = try? Data(contentsOf: tokensFileURL),
               let decoded = try? JSONDecoder().decode([OTPToken].self, from: raw) {
                tokens = decoded
            }
        }
    }

    func saveTokens() {
        do {
            let data = try JSONEncoder().encode(tokens)
            let encrypted = try EncryptionService.encrypt(data)
            try encrypted.write(to: tokensFileURL, options: .atomic)
        } catch {}
    }

    private func loadGroups() {
        guard FileManager.default.fileExists(atPath: groupsFileURL.path) else { return }
        if let data = try? Data(contentsOf: groupsFileURL),
           let decoded = try? JSONDecoder().decode([TokenGroup].self, from: data) {
            groups = decoded
        }
    }

    func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            try? data.write(to: groupsFileURL, options: .atomic)
        }
    }

    private func loadTrash() {
        guard FileManager.default.fileExists(atPath: trashFileURL.path) else { return }
        do {
            let encrypted = try Data(contentsOf: trashFileURL)
            let decrypted = try EncryptionService.decrypt(encrypted)
            trashedTokens = try JSONDecoder().decode([TrashedToken].self, from: decrypted)
        } catch {
            if let raw = try? Data(contentsOf: trashFileURL),
               let decoded = try? JSONDecoder().decode([TrashedToken].self, from: raw) {
                trashedTokens = decoded
            }
        }
    }

    func saveTrash() {
        if trashedTokens.isEmpty {
            try? FileManager.default.removeItem(at: trashFileURL)
            return
        }
        do {
            let data = try JSONEncoder().encode(trashedTokens)
            let encrypted = try EncryptionService.encrypt(data)
            try encrypted.write(to: trashFileURL, options: .atomic)
        } catch {}
    }

    func loadSettings() {
        guard FileManager.default.fileExists(atPath: settingsFileURL.path) else { return }
        if let data = try? Data(contentsOf: settingsFileURL),
           let decoded = try? JSONDecoder().decode(AppSettingsData.self, from: data) {
            settings = decoded
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsFileURL, options: .atomic)
        }
    }

    func addToken(_ token: OTPToken) {
        var newToken = token
        newToken.sortOrder = tokens.count
        tokens.append(newToken)
        saveTokens()
        onTokensChanged?()
    }

    func updateToken(_ token: OTPToken) {
        if let index = tokens.firstIndex(where: { $0.id == token.id }) {
            tokens[index] = token
            tokens[index].updatedAt = Date()
            saveTokens()
        }
    }

    func trashToken(id: UUID) {
        guard let index = tokens.firstIndex(where: { $0.id == id }) else { return }
        let token = tokens.remove(at: index)
        let trashed = TrashedToken(token: token, deletedAt: Date())
        trashedTokens.append(trashed)
        saveTokens()
        saveTrash()
        onTokensChanged?()
    }

    func deleteToken(id: UUID) {
        tokens.removeAll { $0.id == id }
        saveTokens()
        onTokensChanged?()
    }

    func restoreToken(id: UUID) {
        guard let index = trashedTokens.firstIndex(where: { $0.token.id == id }) else { return }
        let restored = trashedTokens.remove(at: index).token
        tokens.append(restored)
        saveTrash()
        saveTokens()
        onTokensChanged?()
    }

    func permanentlyDeleteTrashedToken(id: UUID) {
        trashedTokens.removeAll { $0.token.id == id }
        saveTrash()
    }

    func emptyTrash() {
        trashedTokens.removeAll()
        saveTrash()
    }

    func cleanupExpiredTrash() {
        guard let days = settings.trashRetention.days else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let before = trashedTokens.count
        trashedTokens.removeAll { $0.deletedAt < cutoff }
        if trashedTokens.count != before {
            saveTrash()
        }
    }

    func incrementCounter(for tokenId: UUID) {
        if let index = tokens.firstIndex(where: { $0.id == tokenId }) {
            tokens[index].counter += 1
            tokens[index].updatedAt = Date()
            saveTokens()
        }
    }

    func addGroup(_ group: TokenGroup) {
        var newGroup = group
        newGroup.sortOrder = groups.count
        groups.append(newGroup)
        saveGroups()
    }

    func updateGroup(_ group: TokenGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups()
        }
    }

    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        for i in tokens.indices where tokens[i].groupId == id {
            tokens[i].groupId = nil
        }
        saveGroups()
        saveTokens()
    }

    func tokensInGroup(_ groupId: UUID?) -> [OTPToken] {
        if let groupId {
            return tokens.filter { $0.groupId == groupId }.sorted { $0.sortOrder < $1.sortOrder }
        }
        return tokens.sorted { $0.sortOrder < $1.sortOrder }
    }

    func tokenCount(for groupId: UUID) -> Int {
        tokens.filter { $0.groupId == groupId }.count
    }

    func importTokens(_ newTokens: [OTPToken]) {
        for token in newTokens {
            if !tokens.contains(where: { $0.secret == token.secret && $0.issuer == token.issuer && $0.account == token.account }) {
                addToken(token)
            }
        }
    }

    func exportData() -> Data? {
        let exportPayload = ExportPayload(tokens: tokens, groups: groups)
        return try? JSONEncoder().encode(exportPayload)
    }

    func importData(_ data: Data) -> Int {
        guard let payload = try? JSONDecoder().decode(ExportPayload.self, from: data) else { return 0 }
        var count = 0
        for group in payload.groups {
            if !groups.contains(where: { $0.id == group.id }) {
                groups.append(group)
                count += 1
            }
        }
        saveGroups()
        for token in payload.tokens {
            if !tokens.contains(where: { $0.secret == token.secret && $0.issuer == token.issuer }) {
                addToken(token)
                count += 1
            }
        }
        return count
    }
}

nonisolated struct ExportPayload: Codable, Sendable {
    let tokens: [OTPToken]
    let groups: [TokenGroup]
}
