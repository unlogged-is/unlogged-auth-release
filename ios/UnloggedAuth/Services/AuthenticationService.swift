import Foundation
import LocalAuthentication
import CryptoKit

@Observable
@MainActor
class AuthenticationService {
    var isUnlocked: Bool = false
    var biometryType: LABiometryType = .none
    var biometricFailed: Bool = false

    /// Number of consecutive failed PIN/password attempts
    var failedAttempts: Int = 0
    /// When the lockout ends (nil if not locked out)
    var lockoutEndDate: Date?

    private let passwordKeychainKey = "app_lock_password"
    private let passwordSaltKeychainKey = "app_lock_password_salt"
    private let pinKeychainKey = "app_lock_pin"
    private let pinSaltKeychainKey = "app_lock_pin_salt"
    private let backupPasswordKeychainKey = "app_backup_password"
    private let failedAttemptsKey = "auth_failed_attempts"
    private let lockoutEndKey = "auth_lockout_end"

    /// Escalating lockout delays in seconds: 5 free tries, then 5, 15, 30, 60, 120, 300
    private let lockoutDelays: [TimeInterval] = [0, 0, 0, 0, 0, 5, 15, 30, 60, 120, 300]

    init() {
        checkBiometryType()
        loadLockoutState()
    }

    func checkBiometryType() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = context.biometryType
        } else {
            biometryType = .none
        }
    }

    var biometryName: String {
        switch biometryType {
        case .none: return "Biometrics"
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

    var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    var isBiometricsAvailable: Bool {
        biometryType != .none
    }

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Device Passcode"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Unlogged Auth"
            )
            if success {
                isUnlocked = true
                biometricFailed = false
            }
            return success
        } catch {
            biometricFailed = true
            return false
        }
    }

    func authenticateWithPassword(_ input: String) -> Bool {
        guard !isLockedOut else { return false }
        guard let stored = KeychainService.loadString(key: passwordKeychainKey),
              let salt = KeychainService.load(key: passwordSaltKeychainKey) else {
            // Legacy: try plaintext comparison for passwords set before hashing
            if let stored = KeychainService.loadString(key: passwordKeychainKey), input == stored {
                // Migrate to hashed + wrapped storage
                setPassword(input)
                authSuccess()
                return true
            }
            return false
        }
        let derived = Self.deriveFromCredential(input, salt: salt)
        let hash = Self.verifyHashFromDerived(derived)
        if hash == stored {
            // Unwrap the DEK
            if EncryptionService.hasWrappedDEK {
                let kek = Self.kekFromDerived(derived)
                EncryptionService.unwrapDEK(with: kek)
            }
            authSuccess()
            return true
        }
        authFailure()
        return false
    }

    func setPassword(_ password: String) {
        let salt = Self.generateSalt()
        let derived = Self.deriveFromCredential(password, salt: salt)
        let hash = Self.verifyHashFromDerived(derived)
        _ = KeychainService.saveString(key: passwordKeychainKey, value: hash)
        _ = KeychainService.save(key: passwordSaltKeychainKey, data: salt)
        // Wrap the DEK so tokens can't be decrypted without the password
        let kek = Self.kekFromDerived(derived)
        EncryptionService.wrapDEK(with: kek)
    }

    func hasPassword() -> Bool {
        KeychainService.loadString(key: passwordKeychainKey) != nil
    }

    func clearPassword() {
        // Restore DEK to keychain before clearing credential
        EncryptionService.restoreCachedKeyToKeychain()
        KeychainService.delete(key: passwordKeychainKey)
        KeychainService.delete(key: passwordSaltKeychainKey)
    }

    // MARK: - PIN

    func authenticateWithPin(_ input: String) -> Bool {
        guard !isLockedOut else { return false }
        guard let stored = KeychainService.loadString(key: pinKeychainKey),
              let salt = KeychainService.load(key: pinSaltKeychainKey) else {
            // Legacy: try plaintext comparison for PINs set before hashing
            if let stored = KeychainService.loadString(key: pinKeychainKey), input == stored {
                // Migrate to hashed + wrapped storage
                setPin(input)
                authSuccess()
                return true
            }
            return false
        }
        let derived = Self.deriveFromCredential(input, salt: salt)
        let hash = Self.verifyHashFromDerived(derived)
        if hash == stored {
            // Unwrap the DEK
            if EncryptionService.hasWrappedDEK {
                let kek = Self.kekFromDerived(derived)
                EncryptionService.unwrapDEK(with: kek)
            }
            authSuccess()
            return true
        }
        authFailure()
        return false
    }

    func setPin(_ pin: String) {
        let salt = Self.generateSalt()
        let derived = Self.deriveFromCredential(pin, salt: salt)
        let hash = Self.verifyHashFromDerived(derived)
        _ = KeychainService.saveString(key: pinKeychainKey, value: hash)
        _ = KeychainService.save(key: pinSaltKeychainKey, data: salt)
        setPinLength(pin.count)
        // Wrap the DEK so tokens can't be decrypted without the PIN
        let kek = Self.kekFromDerived(derived)
        EncryptionService.wrapDEK(with: kek)
    }

    func hasPin() -> Bool {
        KeychainService.loadString(key: pinKeychainKey) != nil
    }

    func clearPin() {
        // Restore DEK to keychain before clearing credential
        EncryptionService.restoreCachedKeyToKeychain()
        KeychainService.delete(key: pinKeychainKey)
        KeychainService.delete(key: pinSaltKeychainKey)
        KeychainService.delete(key: "app_lock_pin_length")
    }

    func storedPinLength() -> Int {
        if let lengthStr = KeychainService.loadString(key: "app_lock_pin_length"),
           let length = Int(lengthStr) {
            return length
        }
        return 4
    }

    func setPinLength(_ length: Int) {
        _ = KeychainService.saveString(key: "app_lock_pin_length", value: "\(length)")
    }

    // MARK: - Device Passcode

    func authenticateWithDevicePasscode() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Unlogged Auth"
            )
            if success {
                isUnlocked = true
            }
            return success
        } catch {
            return false
        }
    }

    // MARK: - Backup Password

    func setBackupPassword(_ password: String) {
        _ = KeychainService.saveString(key: backupPasswordKeychainKey, value: password)
    }

    func getBackupPassword() -> String? {
        KeychainService.loadString(key: backupPasswordKeychainKey)
    }

    func hasBackupPassword() -> Bool {
        KeychainService.loadString(key: backupPasswordKeychainKey) != nil
    }

    func clearBackupPassword() {
        KeychainService.delete(key: backupPasswordKeychainKey)
    }

    func lock(lockMethod: LockMethod = .none) {
        isUnlocked = false
        biometricFailed = false
        // Clear cached DEK for credential-based lock methods
        if lockMethod == .pin || lockMethod == .password {
            EncryptionService.clearCachedKey()
        }
    }

    func unlock() {
        isUnlocked = true
    }

    // MARK: - Brute Force Protection

    /// Whether the user is currently locked out
    var isLockedOut: Bool {
        guard let end = lockoutEndDate else { return false }
        return Date() < end
    }

    /// Seconds remaining in lockout
    var lockoutRemainingSeconds: Int {
        guard let end = lockoutEndDate else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSinceNow)))
    }

    private func authSuccess() {
        isUnlocked = true
        failedAttempts = 0
        lockoutEndDate = nil
        saveLockoutState()
    }

    private func authFailure() {
        failedAttempts += 1
        let delayIndex = min(failedAttempts, lockoutDelays.count - 1)
        let delay = lockoutDelays[delayIndex]
        if delay > 0 {
            lockoutEndDate = Date().addingTimeInterval(delay)
        }
        saveLockoutState()
    }

    private func saveLockoutState() {
        UserDefaults.standard.set(failedAttempts, forKey: failedAttemptsKey)
        if let end = lockoutEndDate {
            UserDefaults.standard.set(end.timeIntervalSince1970, forKey: lockoutEndKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lockoutEndKey)
        }
    }

    private func loadLockoutState() {
        failedAttempts = UserDefaults.standard.integer(forKey: failedAttemptsKey)
        let endTimestamp = UserDefaults.standard.double(forKey: lockoutEndKey)
        if endTimestamp > 0 {
            let end = Date(timeIntervalSince1970: endTimestamp)
            lockoutEndDate = Date() < end ? end : nil
        }
    }

    // MARK: - Key Derivation

    private static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    /// Expensive key derivation: 100K iterations of HMAC-SHA256.
    /// Called once per auth attempt, then split into verify hash and KEK.
    private static func deriveFromCredential(_ credential: String, salt: Data) -> Data {
        guard let credentialData = credential.data(using: .utf8) else { return Data() }
        let key = SymmetricKey(data: salt)
        var result = credentialData
        for _ in 0..<100_000 {
            let mac = HMAC<SHA256>.authenticationCode(for: result, using: key)
            result = Data(mac)
        }
        return result
    }

    /// Derive a verification hash from the base derivation (for credential comparison)
    private static func verifyHashFromDerived(_ derived: Data) -> String {
        let key = SymmetricKey(data: derived)
        let mac = HMAC<SHA256>.authenticationCode(for: Data("verify".utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    /// Derive a Key Encryption Key from the base derivation (for DEK wrapping)
    private static func kekFromDerived(_ derived: Data) -> SymmetricKey {
        let key = SymmetricKey(data: derived)
        let mac = HMAC<SHA256>.authenticationCode(for: Data("wrap".utf8), using: key)
        return SymmetricKey(data: Data(mac))
    }
}
