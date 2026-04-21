import Foundation

nonisolated enum Base32: Sendable {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    private static let padding: Character = "="

    static func decode(_ input: String) -> Data? {
        let cleaned = input.uppercased().replacingOccurrences(of: "=", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        guard !cleaned.isEmpty else { return nil }

        let lookup: [Character: UInt8] = {
            var map = [Character: UInt8]()
            for (i, c) in alphabet.enumerated() {
                map[c] = UInt8(i)
            }
            return map
        }()

        var bits: UInt64 = 0
        var bitCount = 0
        var result = Data()

        for char in cleaned {
            guard let value = lookup[char] else { return nil }
            bits = (bits << 5) | UInt64(value)
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                result.append(UInt8((bits >> bitCount) & 0xFF))
            }
        }

        return result
    }

    static func encode(_ data: Data) -> String {
        var result = ""
        var bits: UInt64 = 0
        var bitCount = 0

        for byte in data {
            bits = (bits << 8) | UInt64(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                let index = Int((bits >> bitCount) & 0x1F)
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
            }
        }

        if bitCount > 0 {
            let index = Int((bits << (5 - bitCount)) & 0x1F)
            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }

        while result.count % 8 != 0 {
            result.append(padding)
        }

        return result
    }
}
