import SwiftUI

struct OnboardingContainerView: View {
    let store: TokenStore
    let authService: AuthenticationService
    let iconFetcher: ServiceIconFetcher
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage: Int = 0

    var body: some View {
        ZStack {
            Color.themedBackground(for: colorScheme)
                .ignoresSafeArea()

            Group {
                switch currentPage {
                case 0:
                    OnboardingWelcomeView(onContinue: { currentPage = 1 })
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 1:
                    OnboardingSecurityView(
                        store: store,
                        authService: authService,
                        onContinue: { currentPage = 2 }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 2:
                    OnboardingImportView(
                        store: store,
                        iconFetcher: iconFetcher,
                        onContinue: { currentPage = 3 }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 3:
                    OnboardingBackupView(
                        store: store,
                        authService: authService,
                        onContinue: { currentPage = 4 }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                default:
                    OnboardingTutorialView(onFinish: {
                        store.settings.hasCompletedOnboarding = true
                        store.saveSettings()
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
        }
        .animation(.snappy, value: currentPage)
    }
}
