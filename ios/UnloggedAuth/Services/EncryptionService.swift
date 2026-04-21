import Foundation
import CryptoKit

nonisolated enum EncryptionService: Sendable {
    private static let encryptionKeyTag = "encryption_key"
    private static let wrappedDEKTag = "wrapped_dek"

    /// In-memory cache of the Data Encryption Key for the current session.
    /// When the DEK is wrapped (PIN/password lock), this is populated after authentication
    /// and cleared on lock. For no-lock/biometric modes, it falls back to the keychain.
    nonisolated(unsafe) private static var _cachedKey: SymmetricKey?

    // MARK: - Active Key

    /// Returns the active encryption key. Checks cache first, then keychain.
    /// Throws if the DEK is wrapped and hasn't been unwrapped yet (requires auth).
    static func getActiveKey() throws -> SymmetricKey {
        if let cached = _cachedKey { return cached }
        // Try loading unwrapped key from keychain (no-lock or biometric mode)
        if let keyData = KeychainService.load(key: encryptionKeyTag) {
            let key = SymmetricKey(data: keyData)
            _cachedKey = key
            return key
        }
        // If there's a wrapped DEK, authentication is required
        if hasWrappedDEK {
            throw EncryptionError.authenticationRequired
        }
        // No key exists — first run, create one
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        _ = KeychainService.save(key: encryptionKeyTag, data: keyData)
        _cachedKey = newKey
        return newKey
    }

    /// Legacy non-throwing accessor for backward compatibility during migration
    static func getOrCreateKey() -> SymmetricKey {
        (try? getActiveKey()) ?? {
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            _ = KeychainService.save(key: encryptionKeyTag, data: keyData)
            _cachedKey = newKey
            return newKey
        }()
    }

    // MARK: - Encrypt / Decrypt

    static func encrypt(_ data: Data) throws -> Data {
        let key = try getActiveKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        return combined
    }

    static func decrypt(_ data: Data) throws -> Data {
        let key = try getActiveKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    static func encrypt(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.encodingFailed
        }
        return try encrypt(data)
    }

    static func decryptString(_ data: Data) throws -> String {
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        return string
    }

    // MARK: - Key Wrapping (PIN/Password protection)

    /// Whether a wrapped DEK exists (meaning tokens are credential-protected)
    static var hasWrappedDEK: Bool {
        KeychainService.load(key: wrappedDEKTag) != nil
    }

    static var hasCachedKey: Bool {
        _cachedKey != nil
    }

    /// Wrap the DEK with a Key Encryption Key derived from a credential.
    /// Removes the unwrapped DEK from keychain so tokens can't be decrypted without the credential.
    static func wrapDEK(with kek: SymmetricKey) {
        // Get the current DEK (from cache or keychain)
        let dek: SymmetricKey
        if let cached = _cachedKey {
            dek = cached
        } else if let keyData = KeychainService.load(key: encryptionKeyTag) {
            dek = SymmetricKey(data: keyData)
        } else {
            // No DEK exists yet — create one
            dek = SymmetricKey(size: .bits256)
        }
        let dekData = dek.withUnsafeBytes { Data($0) }
        guard let sealedBox = try? AES.GCM.seal(dekData, using: kek),
              let combined = sealedBox.combined else { return }
        _ = KeychainService.save(key: wrappedDEKTag, data: combined)
        // Remove unwrapped key from keychain
        KeychainService.delete(key: encryptionKeyTag)
        _cachedKey = dek
    }

    /// Unwrap the DEK using a KEK derived from the user's credential.
    /// Returns true if unwrapping succeeded (credential was correct).
    @discardableResult
    static func unwrapDEK(with kek: SymmetricKey) -> Bool {
        guard let wrappedData = KeychainService.load(key: wrappedDEKTag) else { return false }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: wrappedData)
            let dekData = try AES.GCM.open(sealedBox, using: kek)
            _cachedKey = SymmetricKey(data: dekData)
            return true
        } catch {
            return false
        }
    }

    /// Re-wrap the DEK with a new KEK (for changing PIN/password).
    static func rewrapDEK(with newKEK: SymmetricKey) {
        guard let dek = _cachedKey else { return }
        let dekData = dek.withUnsafeBytes { Data($0) }
        guard let sealedBox = try? AES.GCM.seal(dekData, using: newKEK),
              let combined = sealedBox.combined else { return }
        _ = KeychainService.save(key: wrappedDEKTag, data: combined)
    }

    /// Unwrap the DEK and restore it to keychain (when removing PIN/password lock).
    static func unwrapAndRestoreToKeychain(with kek: SymmetricKey) -> Bool {
        guard unwrapDEK(with: kek) else { return false }
        if let key = _cachedKey {
            let keyData = key.withUnsafeBytes { Data($0) }
            _ = KeychainService.save(key: encryptionKeyTag, data: keyData)
            KeychainService.delete(key: wrappedDEKTag)
        }
        return true
    }

    /// Restore the cached DEK to keychain without credential (for switching from PIN/password to biometric/none).
    /// Only works if the DEK is currently cached in memory.
    static func restoreCachedKeyToKeychain() {
        guard let key = _cachedKey else { return }
        let keyData = key.withUnsafeBytes { Data($0) }
        _ = KeychainService.save(key: encryptionKeyTag, data: keyData)
        KeychainService.delete(key: wrappedDEKTag)
    }

    /// Clear the cached key from memory (called on lock)
    static func clearCachedKey() {
        _cachedKey = nil
    }
}

nonisolated enum EncryptionError: Error, Sendable, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case encodingFailed
    case decodingFailed
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Failed to encrypt data"
        case .decryptionFailed: return "Failed to decrypt data"
        case .encodingFailed: return "Failed to encode data"
        case .decodingFailed: return "Failed to decode data"
        case .authenticationRequired: return "Authentication required to access encrypted data"
        }
    }
}
