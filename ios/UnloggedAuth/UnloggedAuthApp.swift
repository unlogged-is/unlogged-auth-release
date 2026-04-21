import SwiftUI

// MARK: - UIKit Privacy Screen

private enum PrivacyScreen {
    static var isEnabled = false
    private static var installed = false
    private static let tag = 98765

    static func install() {
        guard !installed else { return }
        installed = true

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { _ in show() }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { _ in hide() }
    }

    private static func show() {
        guard isEnabled,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              window.viewWithTag(tag) == nil else { return }

        let cover = UIView(frame: window.bounds)
        cover.tag = tag
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cover.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 40/255, green: 35/255, blue: 30/255, alpha: 1)
                : UIColor(red: 250/255, green: 245/255, blue: 237/255, alpha: 1)
        }

        // App icon
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let iconImage = UIImage(named: "AppIconImage") {
            let iconView = UIImageView(image: iconImage)
            iconView.contentMode = .scaleAspectFit
            iconView.layer.cornerRadius = 18
            iconView.clipsToBounds = true
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true
            stack.addArrangedSubview(iconView)
        }

        // App name
        let nameLabel = UILabel()
        nameLabel.text = "unlogged Auth"
        nameLabel.font = UIFont(name: "Lora-Bold", size: 24) ?? .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .black
        }
        stack.addArrangedSubview(nameLabel)

        cover.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
        ])

        window.addSubview(cover)
    }

    private static func hide() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        window.viewWithTag(tag)?.removeFromSuperview()
    }
}

// MARK: - App

@main
struct UnloggedAuthApp: App {
    @State private var store = TokenStore()
    @State private var authService = AuthenticationService()
    @State private var iconFetcher = ServiceIconFetcher()

    init() {
        FontRegistration.registerFonts()
        AppearanceSetup.configureNavigationBar()
        AppearanceSetup.configureGlobalAppearance()
        PrivacyScreen.install()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if !store.settings.hasCompletedOnboarding {
                        OnboardingContainerView(
                            store: store,
                            authService: authService,
                            iconFetcher: iconFetcher
                        )
                    } else {
                        ContentView(
                            store: store,
                            authService: authService,
                            iconFetcher: iconFetcher
                        )
                    }
                }

                // Lock screen always rendered, visibility toggled via opacity (instant)
                if store.settings.hasCompletedOnboarding && store.settings.lockMethod != .none {
                    LockScreenView(
                        authService: authService,
                        lockMethod: store.settings.lockMethod
                    )
                    .opacity(authService.isUnlocked ? 0 : 1)
                    .allowsHitTesting(!authService.isUnlocked)
                }
            }
            .tint(Color("AccentColor"))
            .themedBackground()
            .preferredColorScheme(store.settings.appTheme.colorScheme)
            .task {
                iconFetcher.fetchIcons(for: store.tokens)
                PrivacyScreen.isEnabled = store.settings.lockMethod != .none
            }
            .onChange(of: store.settings.lockMethod) { _, newValue in
                PrivacyScreen.isEnabled = newValue != .none
            }
            .onChange(of: authService.isUnlocked) { _, unlocked in
                if unlocked && EncryptionService.hasCachedKey {
                    // Reload tokens after successful authentication (DEK now available)
                    store.loadAll()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Lock when fully backgrounded (not on inactive, so pulling
                // down notification center won't force re-authentication)
                if store.settings.lockMethod != .none {
                    authService.lock(lockMethod: store.settings.lockMethod)
                }
                if store.settings.autoBackupEnabled {
                    if let password = authService.getBackupPassword() {
                        BackupService.performAutoBackup(store: store, password: password)
                    }
                }
            }
        }
    }
}
