import Foundation

nonisolated struct TokenGroup: Codable, Identifiable, Sendable, Hashable {
    var id: UUID
    var name: String
    var iconSymbol: String
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String = "folder.fill",
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
