import SwiftUI

@main
struct IronClawRemoteApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .preferredColorScheme(.dark)
        }
    }
}
