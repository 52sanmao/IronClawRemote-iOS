import SwiftUI

struct LeftSidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            ClawPalette.panel.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: ClawSpacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("铁爪远控")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(ClawPalette.textPrimary)
                        Text(appState.gatewayStatus?.llmModel ?? "未获取模型信息")
                            .font(.footnote)
                            .foregroundStyle(ClawPalette.textSecondary)
                    }
                    .padding(.bottom, ClawSpacing.sm)

                    ForEach(appState.sidebarGroups) { group in
                        VStack(alignment: .leading, spacing: ClawSpacing.xs) {
                            Text(group.title)
                                .font(.caption)
                                .foregroundStyle(ClawPalette.textSecondary)
                                .padding(.horizontal, 6)

                            ForEach(group.items) { item in
                                Button {
                                    appState.select(item)
                                } label: {
                                    HStack(spacing: ClawSpacing.sm) {
                                        Circle()
                                            .fill(appState.selectedDestination == item ? ClawPalette.accent : ClawPalette.textSecondary.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                        Text(item.rawValue)
                                            .foregroundStyle(ClawPalette.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, ClawSpacing.sm)
                                    .padding(.vertical, 10)
                                    .background(appState.selectedDestination == item ? ClawPalette.accentSoft : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(ClawSpacing.sm)
                        .clawCard()
                    }

                    if appState.currentPane == .chat {
                        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
                            HStack {
                                Text("会话列表")
                                    .font(.headline)
                                    .foregroundStyle(ClawPalette.textPrimary)
                                Spacer()
                                Button("新建") {
                                    Task { await AppBootstrapper.createNewThread(appState: appState) }
                                }
                                .buttonStyle(.bordered)
                            }

                            if let assistant = appState.assistantThread {
                                Button {
                                    appState.select(.assistant)
                                    appState.streamingText = ""
                                    appState.pendingGate = nil
                                    appState.currentThreadID = assistant.id
                                    Task { await AppBootstrapper.refreshHistory(appState: appState, threadID: assistant.id) }
                                } label: {
                                    ThreadRow(thread: assistant, isSelected: appState.currentThreadID == assistant.id)
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(appState.threads) { thread in
                                Button {
                                    appState.select(.conversations)
                                    appState.streamingText = ""
                                    appState.pendingGate = nil
                                    appState.currentThreadID = thread.id
                                    Task { await AppBootstrapper.refreshHistory(appState: appState, threadID: thread.id) }
                                } label: {
                                    ThreadRow(thread: thread, isSelected: appState.currentThreadID == thread.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(ClawSpacing.sm)
                        .clawCard()
                    }
                }
                .padding(ClawSpacing.md)
            }
        }
    }
}

private struct ThreadRow: View {
    let thread: ThreadInfo
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.title ?? titleFallback)
                .foregroundStyle(ClawPalette.textPrimary)
                .lineLimit(1)
            Text(thread.updatedAt)
                .font(.caption2)
                .foregroundStyle(ClawPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isSelected ? ClawPalette.accentSoft : ClawPalette.elevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var titleFallback: String {
        thread.threadType == "assistant" ? "助手会话" : "未命名会话"
    }
}
