import SwiftUI

struct MainWorkspaceView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            ClawPalette.background.ignoresSafeArea()

            switch appState.currentPane {
            case .chat:
                ChatHomeView(appState: appState)
            case .memory:
                MemoryCenterView(appState: appState)
            case .jobs:
                JobsCenterView(appState: appState)
            case .missions:
                MissionsCenterView(appState: appState)
            case .routines:
                RoutinesCenterView(appState: appState)
            case .extensions, .skills, .mcp, .settings:
                SettingsHubView(appState: appState)
            case .logs:
                LogsCenterView(appState: appState)
            case .account:
                AccountCenterView(appState: appState)
            }
        }
    }
}
