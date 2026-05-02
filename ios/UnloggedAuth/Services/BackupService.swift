import Foundation
import CryptoKit
import UniformTypeIdentifiers

nonisolated struct ULAuthBackup: Codable, Sendable {
    let version: Int
    let createdAt: Date
    let salt: Data
    let iv: Data
    let encryptedPayload: Data
}

extension UTType {
    static let ulauth = UTType(exportedAs: "app.rork.unloggedauth.backup", conformingTo: .data)
}

@MainActor
enum BackupService {

    enum BackupError: Error, LocalizedError {
        case noData
        case encryptionFailed
        case decryptionFailed
        case invalidPassword
        case invalidFormat
        case writeFailed
        case webdavFailed(Int)
        case webdavNotConfigured

        var errorDescription: String? {
            switch self {
            case .noData: return "No data to backup"
            case .encryptionFailed: return "Failed to encrypt backup"
            case .decryptionFailed: return "Failed to decrypt backup"
            case .invalidPassword: return "Incorrect password"
            case .invalidFormat: return "Invalid backup file"
            case .writeFailed: return "Failed to write backup file"
            case .webdavFailed(let code): return "WebDAV server returned error \(code)"
            case .webdavNotConfigured: return "WebDAV server is not configured"
            }
        }
    }

    static func createEncryptedBackup(store: TokenStore, password: String) throws -> (data: Data, filename: String) {
        guard let payload = store.exportData() else { throw BackupError.noData }

        let salt = generateSalt()
        let key = deriveKeyV2(from: password, salt: salt)
        let iv = AES.GCM.Nonce()

        let sealedBox = try AES.GCM.seal(payload, using: key, nonce: iv)
        guard let combined = sealedBox.combined else { throw BackupError.encryptionFailed }

        let ivData = Data(iv)

        let backup = ULAuthBackup(
            version: 2,
            createdAt: Date(),
            salt: salt,
            iv: ivData,
            encryptedPayload: combined
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy-HHmmss"
        let filename = "backup-\(formatter.string(from: Date())).ulauth"

        return (data, filename)
    }

    static func restoreFromBackup(data: Data, password: String) throws -> Data {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(ULAuthBackup.self, from: data) else {
            throw BackupError.invalidFormat
        }

        let key: SymmetricKey
        if backup.version >= 2 {
            key = deriveKeyV2(from: password, salt: backup.salt)
        } else {
            key = deriveKeyV1(from: password, salt: backup.salt)
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: backup.encryptedPayload)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return decrypted
        } catch {
            throw BackupError.invalidPassword
        }
    }

    // MARK: - Auto Backup (fire-and-forget, called on token changes and app background)

    static func performAutoBackup(store: TokenStore, password: String) {
        guard store.settings.autoBackupEnabled else { return }

        switch store.settings.backupDestination {
        case .none:
            break
        case .local:
            autoBackupToLocal(store: store, password: password)
        case .icloud:
            autoBackupToiCloud(store: store, password: password)
        case .webdav:
            Task { await autoBackupToWebDAV(store: store, password: password) }
        }
    }

    // MARK: - Manual Backup (awaitable, returns nil on success or error message)

    static func performManualBackup(store: TokenStore, password: String) async -> String? {
        let destination: BackupDestination
        if store.settings.autoBackupEnabled && store.settings.backupDestination != .none {
            destination = store.settings.backupDestination
        } else {
            destination = .local
        }

        do {
            let result = try createEncryptedBackup(store: store, password: password)

            switch destination {
            case .none:
                return "No backup destination selected."
            case .local:
                let backupDir = localBackupDirectory()
                try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
                let fileURL = backupDir.appendingPathComponent(backupFileName)
                try result.data.write(to: fileURL, options: .atomic)
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    return "File write succeeded but file not found at: \(fileURL.path)"
                }
            case .icloud:
                guard let backupDir = iCloudBackupDirectory() else {
                    return "iCloud Drive is not available. Check that iCloud is enabled in Settings."
                }
                try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
                let fileURL = backupDir.appendingPathComponent(backupFileName)
                try result.data.write(to: fileURL, options: .atomic)
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    return "File write succeeded but file not found at: \(fileURL.path)"
                }
            case .webdav:
                let config = store.settings.webdavConfig
                guard !config.serverURL.isEmpty else {
                    return "WebDAV server URL is not configured."
                }
                let baseURL = config.serverURL.hasSuffix("/") ? config.serverURL : config.serverURL + "/"
                let path = config.path.hasPrefix("/") ? String(config.path.dropFirst()) : config.path
                let fullPath = path.hasSuffix("/") ? path : path + "/"
                guard let uploadURL = URL(string: baseURL + fullPath + backupFileName) else {
                    return "Invalid WebDAV URL: \(baseURL + fullPath + backupFileName)"
                }
                var request = URLRequest(url: uploadURL)
                request.httpMethod = "PUT"
                request.httpBody = result.data
                let credentials = "\(config.username):\(config.password)"
                if let credData = credentials.data(using: .utf8) {
                    request.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
                }
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    return "WebDAV server returned error \(code)."
                }
            }

            store.settings.lastBackupDate = Date()
            store.saveSettings()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Local Backup

    private static func backupToLocal(store: TokenStore, password: String) -> Bool {
        guard let result = try? createEncryptedBackup(store: store, password: password) else { return false }
        let backupDir = localBackupDirectory()
        do {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let fileURL = backupDir.appendingPathComponent(backupFileName)
            try result.data.write(to: fileURL, options: .atomic)
            store.settings.lastBackupDate = Date()
            store.saveSettings()
            return true
        } catch {
            return false
        }
    }

    private static func autoBackupToLocal(store: TokenStore, password: String) {
        _ = backupToLocal(store: store, password: password)
    }

    // MARK: - iCloud Backup

    private static func backupToiCloud(store: TokenStore, password: String) -> Bool {
        guard let result = try? createEncryptedBackup(store: store, password: password),
              let backupDir = iCloudBackupDirectory() else {
            return false
        }
        do {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let fileURL = backupDir.appendingPathComponent(backupFileName)
            try result.data.write(to: fileURL, options: .atomic)
            store.settings.lastBackupDate = Date()
            store.saveSettings()
            return true
        } catch {
            return false
        }
    }

    private static func autoBackupToiCloud(store: TokenStore, password: String) {
        if !backupToiCloud(store: store, password: password) {
            _ = backupToLocal(store: store, password: password)
        }
    }

    // MARK: - WebDAV Backup

    private static func backupToWebDAV(store: TokenStore, password: String) async -> Bool {
        guard let result = try? createEncryptedBackup(store: store, password: password) else { return false }
        let config = store.settings.webdavConfig
        guard !config.serverURL.isEmpty else { return false }

        let baseURL = config.serverURL.hasSuffix("/") ? config.serverURL : config.serverURL + "/"
        let path = config.path.hasPrefix("/") ? String(config.path.dropFirst()) : config.path
        let fullPath = path.hasSuffix("/") ? path : path + "/"

        guard let uploadURL = URL(string: baseURL + fullPath + backupFileName) else { return false }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = result.data

        let credentials = "\(config.username):\(config.password)"
        if let credData = credentials.data(using: .utf8) {
            request.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return false
            }
            store.settings.lastBackupDate = Date()
            store.saveSettings()
            return true
        } catch {
            return false
        }
    }

    private static func autoBackupToWebDAV(store: TokenStore, password: String) async {
        _ = await backupToWebDAV(store: store, password: password)
    }

    // MARK: - Paths

    static let backupFolderName = "unlogged Auth"
    static let backupFileName = "backup.ulauth"

    static func localBackupDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(backupFolderName)
    }

    static func iCloudBackupDirectory() -> URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        return containerURL.appendingPathComponent("Documents").appendingPathComponent(backupFolderName)
    }

    // MARK: - Key Derivation

    private static func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        return salt
    }

    private static func deriveKeyV1(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            outputByteCount: 32
        )
        return derived
    }

    private static func deriveKeyV2(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let key = SymmetricKey(data: salt)
        var result = passwordData
        for _ in 0..<100_000 {
            let mac = HMAC<SHA256>.authenticationCode(for: result, using: key)
            result = Data(mac)
        }
        return SymmetricKey(data: result)
    }
}
