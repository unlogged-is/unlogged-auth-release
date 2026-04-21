import Foundation
import CryptoKit

nonisolated struct OTPGenerator: Sendable {

    static func generateTOTP(secret: Data, algorithm: OTPAlgorithm, digits: Int, period: Int, date: Date = Date()) -> String {
        let counter = UInt64(date.timeIntervalSince1970) / UInt64(period)
        return generateHOTP(secret: secret, algorithm: algorithm, digits: digits, counter: counter)
    }

    static func generateHOTP(secret: Data, algorithm: OTPAlgorithm, digits: Int, counter: UInt64) -> String {
        var bigCounter = counter.bigEndian
        let counterData = Data(bytes: &bigCounter, count: MemoryLayout<UInt64>.size)

        let hash: Data
        let key = SymmetricKey(data: secret)

        switch algorithm {
        case .sha1:
            let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
            hash = Data(mac)
        case .sha256:
            let mac = HMAC<SHA256>.authenticationCode(for: counterData, using: key)
            hash = Data(mac)
        case .sha512:
            let mac = HMAC<SHA512>.authenticationCode(for: counterData, using: key)
            hash = Data(mac)
        }

        let offset = Int(hash[hash.count - 1] & 0x0f)

        let truncatedHash = hash.withUnsafeBytes { ptr -> UInt32 in
            let start = ptr.baseAddress!.advanced(by: offset)
            var value: UInt32 = 0
            memcpy(&value, start, 4)
            return UInt32(bigEndian: value)
        }

        let code = truncatedHash & 0x7FFF_FFFF
        let mod = UInt32(pow(10, Double(digits)))
        return String(format: "%0*u", digits, code % mod)
    }

    static func generate(for token: OTPToken) -> String {
        guard let secretData = Base32.decode(token.secret) else { return String(repeating: "-", count: token.digits) }
        switch token.type {
        case .totp:
            return generateTOTP(secret: secretData, algorithm: token.algorithm, digits: token.digits, period: token.period)
        case .hotp:
            return generateHOTP(secret: secretData, algorithm: token.algorithm, digits: token.digits, counter: token.counter)
        }
    }

    static func generateNext(for token: OTPToken) -> String {
        guard token.type == .totp else { return "" }
        guard let secretData = Base32.decode(token.secret) else { return String(repeating: "-", count: token.digits) }
        let nextDate = Date().addingTimeInterval(Double(token.period))
        return generateTOTP(secret: secretData, algorithm: token.algorithm, digits: token.digits, period: token.period, date: nextDate)
    }

    static func remainingSeconds(for period: Int, date: Date = Date()) -> Double {
        let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(period))
        return Double(period) - elapsed
    }

    static func progress(for period: Int, date: Date = Date()) -> Double {
        let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(period))
        return elapsed / Double(period)
    }

    static func formatCode(_ code: String) -> String {
        let mid = code.count / 2
        let left = code.prefix(mid)
        let right = code.suffix(code.count - mid)
        return "\(left) \(right)"
    }
}
