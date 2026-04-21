import SwiftUI

struct ContentView: View {
    let store: TokenStore
    let authService: AuthenticationService
    let iconFetcher: ServiceIconFetcher

    var body: some View {
        TabView {
            Tab("Tokens", systemImage: "key.fill") {
                TokensListView(store: store, iconFetcher: iconFetcher)
            }

            Tab("Groups", systemImage: "folder.fill") {
                GroupsView(store: store, iconFetcher: iconFetcher)
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView(store: store, authService: authService, iconFetcher: iconFetcher)
            }
        }
        .tint(.accent)
    }
}
