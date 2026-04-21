import SwiftUI

struct AppShellView: View {
    @Bindable var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationSplitView {
            LeftSidebarView(appState: appState)
                .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 320)
        } content: {
            MainWorkspaceView(appState: appState)
                .navigationSplitViewColumnWidth(min: 540, ideal: 720, max: .infinity)
        } detail: {
            RightInspectorView(appState: appState)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        }
        .tint(ClawPalette.accent)
        .background(ClawPalette.background)
    }
}
