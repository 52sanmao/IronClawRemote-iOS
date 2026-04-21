import SwiftUI

struct LogsCenterView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClawSpacing.md) {
                centerHeader(title: "运行日志", subtitle: "实时展示网关日志流，并预留级别切换与目标过滤的二级内容。") {
                    HStack(spacing: ClawSpacing.sm) {
                        Button("刷新级别") {
                            Task { await AppBootstrapper.refreshLogLevel(appState: appState) }
                        }
                        .buttonStyle(.bordered)

                        Button("清空") {
                            appState.logEntries = []
                            appState.selectedLogEntryID = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ClawPalette.accent)
                    }
                }

                infoPanel(title: "日志概览") {
                    HStack {
                        LabeledValue(label: "当前级别", value: appState.logLevel)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(["TRACE", "DEBUG", "INFO", "WARN", "ERROR"], id: \.self) { level in
                                Button {
                                    Task {
                                        await AppBootstrapper.setLogLevel(appState: appState, level: level)
                                    }
                                } label: {
                                    Text(level)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(appState.logLevel == level ? ClawPalette.accentSoft : ClawPalette.elevated)
                                        .foregroundStyle(appState.logLevel == level ? ClawPalette.accent : ClawPalette.textSecondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    LabeledValue(label: "日志条目", value: "\(appState.logEntries.count)")
                    LabeledValue(label: "最近目标", value: appState.logEntries.first?.target ?? "暂无")
                }

                splitDetailShell {
                    infoPanel(title: "实时日志") {
                        if appState.logEntries.isEmpty {
                            placeholderText("正在等待日志流，或当前网关暂无新日志。")
                        } else {
                            ForEach(appState.logEntries.prefix(60)) { entry in
                                Button {
                                    appState.selectedLogEntryID = entry.id
                                } label: {
                                    selectableRow(
                                        title: entry.message,
                                        subtitle: entry.target,
                                        isSelected: appState.selectedLogEntryID == entry.id,
                                        trailing: entry.level.uppercased(),
                                        tint: levelColor(entry.level)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } detail: {
                    if let entry = selectedLogEntry {
                        VStack(alignment: .leading, spacing: ClawSpacing.md) {
                            detailCard(
                                title: "日志详情",
                                badge: entry.level.uppercased(),
                                lines: [
                                    ("时间", entry.timestamp),
                                    ("目标", entry.target),
                                    ("当前级别", appState.logLevel)
                                ],
                                description: entry.message,
                                footer: "后续会在这里补日志级别切换、目标筛选和搜索。"
                            )

                            infoPanel(title: "日志操作") {
                                LabeledValue(label: "级别切换", value: "已支持")
                                LabeledValue(label: "目标过滤", value: "待实现")
                                LabeledValue(label: "搜索", value: "待实现")
                            }
                        }
                    } else {
                        detailCard(
                            title: "日志详情",
                            lines: [("状态", "暂无日志"), ("二级内容", "详情 / 过滤 / 搜索")],
                            description: "日志到达后，这里会显示当前选中日志的详情与过滤能力。"
                        )
                    }
                }
            }
            .padding(ClawSpacing.md)
        }
        .background(ClawPalette.background)
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
