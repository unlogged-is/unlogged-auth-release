import Foundation

nonisolated enum OTPType: String, Codable, Sendable, CaseIterable {
    case totp
    case hotp
}

nonisolated enum OTPAlgorithm: String, Codable, Sendable, CaseIterable {
    case sha1
    case sha256
    case sha512

    var displayName: String {
        switch self {
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sha512: return "SHA-512"
        }
    }
}

nonisolated struct OTPToken: Codable, Identifiable, Sendable, Hashable {
    var id: UUID
    var issuer: String
    var account: String
    var secret: String
    var type: OTPType
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: Int
    var counter: UInt64
    var groupId: UUID?
    var iconSymbol: String?
    var iconColor: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        issuer: String,
        account: String,
        secret: String,
        type: OTPType = .totp,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: UInt64 = 0,
        groupId: UUID? = nil,
        iconSymbol: String? = nil,
        iconColor: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.issuer = issuer
        self.account = account
        self.secret = secret
        self.type = type
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.counter = counter
        self.groupId = groupId
        self.iconSymbol = iconSymbol
        self.iconColor = iconColor
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated struct TrashedToken: Codable, Identifiable, Sendable {
    var id: UUID { token.id }
    var token: OTPToken
    var deletedAt: Date

    var daysInTrash: Int {
        Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
    }
}
