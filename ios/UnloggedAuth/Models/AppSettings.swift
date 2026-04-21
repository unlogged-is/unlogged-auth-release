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

    init(
        lockMethod: LockMethod = .none,
        autoBackupEnabled: Bool = false,
        backupDestination: BackupDestination = .none,
        webdavConfig: WebDAVConfig = WebDAVConfig(),
        hasCompletedOnboarding: Bool = false,
        lastBackupDate: Date? = nil,
        appTheme: AppTheme = .dark,
        hasSetBackupPassword: Bool = false,
        focusSearchOnLaunch: Bool = false
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
    }
}
