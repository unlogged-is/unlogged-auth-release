import SwiftUI

struct ContentView: View {
    let store: TokenStore
    let authService: AuthenticationService
    let iconFetcher: ServiceIconFetcher
    
    // iPhone Duo optimizations
    @State private var deviceCapabilities = DeviceCapabilities.shared

    var body: some View {
        Group {
            if deviceCapabilities.shouldUseTwoColumnLayout {
                TabView {
                    Tab("Tokens", systemImage: "key.fill") {
                        TokensListView(store: store, authService: authService, iconFetcher: iconFetcher)
                    }

                    Tab("Groups", systemImage: "folder.fill") {
                        GroupsView(store: store, iconFetcher: iconFetcher)
                    }

                    Tab("Settings", systemImage: "gearshape.fill") {
                        SettingsView(store: store, authService: authService, iconFetcher: iconFetcher)
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else {
                TabView {
                    Tab("Tokens", systemImage: "key.fill") {
                        TokensListView(store: store, authService: authService, iconFetcher: iconFetcher)
                    }

                    Tab("Groups", systemImage: "folder.fill") {
                        GroupsView(store: store, iconFetcher: iconFetcher)
                    }

                    Tab("Settings", systemImage: "gearshape.fill") {
                        SettingsView(store: store, authService: authService, iconFetcher: iconFetcher)
                    }
                }
                .tabViewStyle(.automatic)
            }
        }
        .tint(.accent)
        .onAppear {
            deviceCapabilities.updateDetection()
        }
    }
}
