import Foundation

nonisolated enum LockMethod: String, Codable, Sendable, CaseIterable {
    case none
    case biometric
    case password
    case pin
    case devicePasscode
}

nonisolated enum AppTheme: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

nonisolated enum TokenSortOrder: String, Codable, Sendable, CaseIterable {
    case name
    case recentlyAdded

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .recentlyAdded: return "Recently Added"
        }
    }
}

nonisolated enum TrashRetention: String, Codable, Sendable, CaseIterable {
    case off
    case fifteenDays
    case thirtyDays

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .fifteenDays: return "15 Days"
        case .thirtyDays: return "30 Days"
        }
    }

    var days: Int? {
        switch self {
        case .off: return nil
        case .fifteenDays: return 15
        case .thirtyDays: return 30
        }
    }
}

nonisolated enum BackupDestination: String, Codable, Sendable, CaseIterable {
    case none
    case local
    case icloud
    case webdav
}

nonisolated struct WebDAVConfig: Codable, Sendable {
    var serverURL: String
    var username: String
    var password: String
    var path: String

    init(serverURL: String = "", username: String = "", password: String = "", path: String = "/unlogged-auth/") {
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.path = path
    }
}

nonisolated struct AppSettingsData: Codable, Sendable {
    var lockMethod: LockMethod
    var autoBackupEnabled: Bool
    var backupDestination: BackupDestination
    var webdavConfig: WebDAVConfig
    var hasCompletedOnboarding: Bool
    var lastBackupDate: Date?
    var appTheme: AppTheme
    var hasSetBackupPassword: Bool
    var focusSearchOnLaunch: Bool
    var tokenSortOrder: TokenSortOrder
    var trashRetention: TrashRetention

    init(
        lockMethod: LockMethod = .none,
        autoBackupEnabled: Bool = false,
        backupDestination: BackupDestination = .none,
        webdavConfig: WebDAVConfig = WebDAVConfig(),
        hasCompletedOnboarding: Bool = false,
        lastBackupDate: Date? = nil,
        appTheme: AppTheme = .dark,
        hasSetBackupPassword: Bool = false,
        focusSearchOnLaunch: Bool = false,
        tokenSortOrder: TokenSortOrder = .name,
        trashRetention: TrashRetention = .thirtyDays
    ) {
        self.lockMethod = lockMethod
        self.autoBackupEnabled = autoBackupEnabled
        self.backupDestination = backupDestination
        self.webdavConfig = webdavConfig
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastBackupDate = lastBackupDate
        self.appTheme = appTheme
        self.hasSetBackupPassword = hasSetBackupPassword
        self.focusSearchOnLaunch = focusSearchOnLaunch
        self.tokenSortOrder = tokenSortOrder
        self.trashRetention = trashRetention
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lockMethod = (try? container.decode(LockMethod.self, forKey: .lockMethod)) ?? .none
        autoBackupEnabled = (try? container.decode(Bool.self, forKey: .autoBackupEnabled)) ?? false
        backupDestination = (try? container.decode(BackupDestination.self, forKey: .backupDestination)) ?? .none
        webdavConfig = (try? container.decode(WebDAVConfig.self, forKey: .webdavConfig)) ?? WebDAVConfig()
        hasCompletedOnboarding = (try? container.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        lastBackupDate = try? container.decode(Date.self, forKey: .lastBackupDate)
        appTheme = (try? container.decode(AppTheme.self, forKey: .appTheme)) ?? .dark
        hasSetBackupPassword = (try? container.decode(Bool.self, forKey: .hasSetBackupPassword)) ?? false
        focusSearchOnLaunch = (try? container.decode(Bool.self, forKey: .focusSearchOnLaunch)) ?? false
        tokenSortOrder = (try? container.decode(TokenSortOrder.self, forKey: .tokenSortOrder)) ?? .name
        trashRetention = (try? container.decode(TrashRetention.self, forKey: .trashRetention)) ?? .thirtyDays
    }
}
