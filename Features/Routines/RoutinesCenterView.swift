import SwiftUI

struct RoutinesCenterView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClawSpacing.md) {
                centerHeader(title: "定时器", subtitle: "查看计划任务、下次触发时间、运行历史与手动操作入口。") {
                    Button("刷新") {
                        Task { await AppBootstrapper.refreshRoutines(appState: appState) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClawPalette.accent)
                }

                infoPanel(title: "运行摘要") {
                    LabeledValue(label: "总数", value: "\(appState.routineSummary?.total ?? 0)")
                    LabeledValue(label: "已启用", value: "\(appState.routineSummary?.enabled ?? 0)")
                    LabeledValue(label: "今日运行", value: "\(appState.routineSummary?.runsToday ?? 0)")
                    LabeledValue(label: "异常", value: "\(appState.routineSummary?.failing ?? 0)")
                }

                splitDetailShell {
                    infoPanel(title: "定时器列表") {
                        if appState.routines.isEmpty {
                            placeholderText("尚未读取到定时器。")
                        } else {
                            ForEach(appState.routines.prefix(30)) { routine in
                                Button {
                                    appState.selectedRoutineID = routine.id
                                    appState.selectedRoutineDetail = nil
                                    appState.routineRuns = []
                                    Task { await AppBootstrapper.loadRoutineDetail(appState: appState, routineID: routine.id) }
                                } label: {
                                    selectableRow(
                                        title: routine.name,
                                        subtitle: routine.triggerSummary,
                                        isSelected: appState.selectedRoutineID == routine.id,
                                        trailing: routine.enabled ? "已启用" : "已停用",
                                        tint: routine.enabled ? ClawPalette.success : ClawPalette.textSecondary
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } detail: {
                    if let routineID = appState.selectedRoutineID, let detail = selectedRoutineDetail, detail.id == routineID {
                        VStack(alignment: .leading, spacing: ClawSpacing.md) {
                            detailCard(
                                title: detail.name,
                                badge: detail.enabled ? "运行中" : "已停用",
                                lines: [
                                    ("定时器 ID", detail.id.uuidString),
                                    ("描述", detail.description),
                                    ("触发类型", detail.triggerType),
                                    ("触发摘要", detail.triggerSummary),
                                    ("下次触发", detail.nextFireAt ?? "未知"),
                                    ("最近运行", detail.lastRunAt ?? "暂无"),
                                    ("运行次数", "\(detail.runCount)"),
                                    ("连续失败", "\(detail.consecutiveFailures)"),
                                    ("验证状态", detail.verificationStatus),
                                    ("状态", detail.status)
                                ]
                            )

                            HStack(spacing: ClawSpacing.sm) {
                                Button(detail.enabled ? "停用" : "启用") {
                                    Task { await AppBootstrapper.toggleRoutine(appState: appState, routineID: routineID, enabled: !detail.enabled) }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(detail.enabled ? ClawPalette.warning : ClawPalette.success)

                                Button("手动触发") {
                                    Task { await AppBootstrapper.triggerRoutine(appState: appState, routineID: routineID) }
                                }
                                .buttonStyle(.bordered)

                                Button("删除") {
                                    Task { await AppBootstrapper.deleteRoutine(appState: appState, routineID: routineID) }
                                }
                                .buttonStyle(.bordered)
                                .tint(ClawPalette.warning)
                            }

                            infoPanel(title: "触发配置") {
                                Text(detail.trigger.prettyString)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(ClawPalette.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }

                            infoPanel(title: "动作配置") {
                                Text(detail.action.prettyString)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(ClawPalette.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }

                            infoPanel(title: "最近运行") {
                                if appState.routineRuns.isEmpty {
                                    placeholderText("暂无运行记录。")
                                } else {
                                    ForEach(appState.routineRuns.prefix(15)) { run in
                                        selectableRow(
                                            title: run.triggerType,
                                            subtitle: run.resultSummary ?? run.startedAt,
                                            trailing: run.status,
                                            tint: run.status.lowercased().contains("fail") ? ClawPalette.warning : ClawPalette.accent
                                        )
                                    }
                                }
                            }
                        }
                    } else if let routineID = appState.selectedRoutineID {
                        detailCard(
                            title: "正在加载",
                            lines: [("定时器 ID", routineID.uuidString)],
                            description: "正在读取定时器详情与运行历史。"
                        )
                    } else {
                        detailCard(
                            title: "定时器详情",
                            lines: [("状态", "未选择定时器"), ("二级内容", "配置 / 历史 / 操作")],
                            description: "从左侧选择一个定时器后，这里会显示完整详情和动作入口。"
                        )
                    }
                }
            }
            .padding(ClawSpacing.md)
        }
        .background(ClawPalette.background)
    }

    private var selectedRoutineDetail: RoutineDetailResponse? {
        guard let routineID = appState.selectedRoutineID else { return nil }
        guard let detail = appState.selectedRoutineDetail, detail.id == routineID else { return nil }
        return detail
    }
}
