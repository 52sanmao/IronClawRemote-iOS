import SwiftUI

struct RootView: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                AppShellView(appState: appState)
                    .task {
                        await AppBootstrapper.bootstrap(appState: appState)
                    }
            } else {
                LoginView(appState: appState)
            }
        }
        .background(ClawPalette.background.ignoresSafeArea())
    }
}
