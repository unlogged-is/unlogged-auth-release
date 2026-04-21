import SwiftUI
import UIKit

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    // Light mode: warm cream
    static let creamBackground = Color(red: 250 / 255.0, green: 245 / 255.0, blue: 237 / 255.0)
    static let creamSecondary = Color(red: 241 / 255.0, green: 235 / 255.0, blue: 225 / 255.0)

    // Dark mode: softer dark
    static let warmDarkBackground = Color(red: 40 / 255.0, green: 35 / 255.0, blue: 30 / 255.0)
    static let warmDarkSecondary = Color(red: 55 / 255.0, green: 48 / 255.0, blue: 42 / 255.0)

    // Adaptive colors
    static func themedBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .warmDarkBackground : .creamBackground
    }

    static func themedSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .warmDarkSecondary : .creamSecondary
    }
}

struct ThemedBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.themedBackground(for: colorScheme).ignoresSafeArea())
    }
}

struct ThemedSecondaryBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.themedSecondary(for: colorScheme))
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }

    func themedSecondaryBackground() -> some View {
        modifier(ThemedSecondaryBackgroundModifier())
    }
}

enum AppearanceSetup {
    static func configureNavigationBar() {
        let accentColor = UIColor(named: "AccentColor") ?? .tintColor
        let loraFont = UIFont(name: "Lora-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        let loraInline = UIFont(name: "Lora-SemiBold", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)

        let largeAttrs: [NSAttributedString.Key: Any] = [.font: loraFont]
        let inlineAttrs: [NSAttributedString.Key: Any] = [.font: loraInline]

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.largeTitleTextAttributes = largeAttrs
        navAppearance.titleTextAttributes = inlineAttrs

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accentColor
    }

    static func configureGlobalAppearance() {
        let accentColor = UIColor(named: "AccentColor") ?? .tintColor

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = accentColor
    }
}
