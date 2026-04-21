import SwiftUI

struct RightInspectorView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            ClawPalette.panel.opacity(0.92).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: ClawSpacing.md) {
                    inspectorHeader

                    switch appState.currentPane {
                    case .chat:
                        ChatInspectorSection(appState: appState)
                    case .memory:
                        MemoryInspectorSection(appState: appState)
                    case .jobs:
                        JobInspectorSection(appState: appState)
                    case .missions:
                        MissionInspectorSection(appState: appState)
                    case .routines:
                        RoutineInspectorSection(appState: appState)
                    case .extensions, .skills, .mcp, .settings:
                        SettingsInspectorSection(appState: appState)
                    case .logs:
                        LogsInspectorSection(appState: appState)
                    case .account:
                        AccountInspectorSection(appState: appState)
                    }
                }
                .padding(ClawSpacing.md)
            }
        }
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("洞察侧栏")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(ClawPalette.textPrimary)
            Text(appState.statusText)
                .font(.footnote)
                .foregroundStyle(ClawPalette.textSecondary)
        }
    }
}

private struct ChatInspectorSection: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            infoCard(title: "会话信息") {
                LabeledValue(label: "当前线程", value: appState.currentThreadID?.uuidString ?? "未选择")
                LabeledValue(label: "待处理确认", value: appState.pendingGate?.gateName ?? "无")
                LabeledValue(label: "网关连接", value: appState.gatewayStatus?.totalConnections.description ?? "离线")
            }

            infoCard(title: "快捷动作") {
                VStack(spacing: ClawSpacing.sm) {
                    actionButton("刷新会话") { Task { await AppBootstrapper.refreshThreads(appState: appState) } }
                    actionButton("刷新状态") { Task { await AppBootstrapper.refreshGatewayStatus(appState: appState) } }
                    actionButton("清空流式文本") { appState.streamingText = "" }
                }
            }

            infoCard(title: "事件流") {
                if appState.inspectorEvents.isEmpty {
                    Text("暂无事件")
                        .foregroundStyle(ClawPalette.textSecondary)
                } else {
                    ForEach(appState.inspectorEvents.prefix(20), id: \.self) { event in
                        Text(event)
                            .font(.footnote)
                            .foregroundStyle(ClawPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(ClawPalette.elevated.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct MemoryInspectorSection: View {
    @Bindable var appState: AppState

    var body: some View {
        infoCard(title: "记忆洞察") {
            LabeledValue(label: "当前文件", value: appState.selectedMemoryFile?.path ?? "未选择")
            LabeledValue(label: "文件总数", value: "\(appState.memoryEntries.filter { !$0.isDir }.count)")
            LabeledValue(label: "目录总数", value: "\(appState.memoryEntries.filter(\.isDir).count)")
        }
    }
}

private struct JobInspectorSection: View {
    @Bindable var appState: AppState
    var body: some View {
        infoCard(title: "任务摘要") {
            LabeledValue(label: "总任务", value: "\(appState.jobSummary?.total ?? 0)")
            LabeledValue(label: "进行中", value: "\(appState.jobSummary?.inProgress ?? 0)")
            LabeledValue(label: "已完成", value: "\(appState.jobSummary?.completed ?? 0)")
            LabeledValue(label: "当前任务", value: appState.selectedJobID?.uuidString ?? "未选择")
        }
    }
}

private struct MissionInspectorSection: View {
    @Bindable var appState: AppState
    var body: some View {
        infoCard(title: "任务流洞察") {
            LabeledValue(label: "任务流数量", value: "\(appState.missions.count)")
            LabeledValue(label: "当前任务流", value: appState.selectedMissionID ?? "未选择")
        }
    }
}

private struct RoutineInspectorSection: View {
    @Bindable var appState: AppState
    var body: some View {
        infoCard(title: "定时器摘要") {
            LabeledValue(label: "总数", value: "\(appState.routineSummary?.total ?? 0)")
            LabeledValue(label: "已启用", value: "\(appState.routineSummary?.enabled ?? 0)")
            LabeledValue(label: "当前定时器", value: appState.selectedRoutineID?.uuidString ?? "未选择")
        }
    }
}

private struct SettingsInspectorSection: View {
    @Bindable var appState: AppState

    var body: some View {
        infoCard(title: "设置上下文") {
            LabeledValue(label: "当前模块", value: appState.currentPane.rawValue)
            LabeledValue(label: "设置分区", value: appState.selectedSettingsCategory.rawValue)
            LabeledValue(label: "能力分区", value: appState.selectedCapabilityCategory.rawValue)
        }
    }
}

private struct AccountInspectorSection: View {
    @Bindable var appState: AppState

    var body: some View {
        infoCard(title: "账户概览") {
            LabeledValue(label: "显示名", value: appState.profile?.displayName ?? "未获取")
            LabeledValue(label: "角色", value: appState.profile?.role ?? "未知")
            LabeledValue(label: "网关版本", value: appState.gatewayStatus?.version ?? "未知")
        }
    }
}

private struct LogsInspectorSection: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            infoCard(title: "日志状态") {
                LabeledValue(label: "日志级别", value: appState.logLevel)
                LabeledValue(label: "实时条目", value: "\(appState.logEntries.count)")
                LabeledValue(label: "当前选中", value: selectedLogEntry?.target ?? "未选择")
            }

            infoCard(title: "最新日志") {
                if appState.logEntries.isEmpty {
                    Text("暂无日志")
                        .foregroundStyle(ClawPalette.textSecondary)
                } else {
                    ForEach(appState.logEntries.prefix(12)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.level.uppercased())
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(levelColor(entry.level))
                                Spacer()
                                Text(entry.timestamp)
                                    .font(.caption2)
                                    .foregroundStyle(ClawPalette.textSecondary)
                            }
                            Text(entry.message)
                                .font(.footnote)
                                .foregroundStyle(ClawPalette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(appState.selectedLogEntryID == entry.id ? ClawPalette.accentSoft : ClawPalette.elevated.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var selectedLogEntry: LogEntry? {
        guard let selectedLogEntryID = appState.selectedLogEntryID else { return appState.logEntries.first }
        return appState.logEntries.first { $0.id == selectedLogEntryID } ?? appState.logEntries.first
    }

    private func levelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "error": return ClawPalette.danger
        case "warn": return ClawPalette.warning
        case "info": return ClawPalette.accent
        default: return ClawPalette.textSecondary
        }
    }
}

struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(ClawPalette.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(ClawPalette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }
}

func infoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: ClawSpacing.sm) {
        Text(title)
            .font(.headline)
            .foregroundStyle(ClawPalette.textPrimary)
        content()
    }
    .padding(ClawSpacing.md)
    .clawCard()
}

func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
        .buttonStyle(.borderedProminent)
        .tint(ClawPalette.accent)
}
