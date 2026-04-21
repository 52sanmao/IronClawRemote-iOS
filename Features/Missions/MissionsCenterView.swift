import SwiftUI

struct MissionsCenterView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClawSpacing.md) {
                centerHeader(title: "任务流", subtitle: "查看长期任务编排、目标、节奏、线程与事件。") {
                    Button("刷新") {
                        Task {
                            await AppBootstrapper.refreshMissions(appState: appState)
                            await AppBootstrapper.refreshEngineThreads(appState: appState)
                            await AppBootstrapper.refreshEngineProjects(appState: appState)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClawPalette.accent)
                }

                if let summary = appState.missionSummary {
                    infoPanel(title: "任务流摘要") {
                        HStack(spacing: ClawSpacing.md) {
                            LabeledValue(label: "总数", value: "\(summary.total)")
                            LabeledValue(label: "活跃", value: "\(summary.active)")
                            LabeledValue(label: "暂停", value: "\(summary.paused)")
                            LabeledValue(label: "完成", value: "\(summary.completed)")
                            LabeledValue(label: "失败", value: "\(summary.failed)")
                        }
                    }
                }

                splitDetailShell {
                    VStack(alignment: .leading, spacing: ClawSpacing.md) {
                        infoPanel(title: "任务流列表") {
                            if appState.missions.isEmpty {
                                placeholderText("尚未读取到任务流。")
                            } else {
                                LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                                    ForEach(appState.missions.prefix(30)) { mission in
                                        Button {
                                            appState.selectedMissionID = mission.id
                                            appState.selectedMissionDetail = nil
                                            Task { await AppBootstrapper.loadMissionDetail(appState: appState, missionID: mission.id) }
                                        } label: {
                                            selectableRow(
                                                title: mission.name,
                                                subtitle: mission.goal,
                                                isSelected: appState.selectedMissionID == mission.id,
                                                trailing: mission.status
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        infoPanel(title: "引擎线程") {
                            if appState.engineThreads.isEmpty {
                                placeholderText("尚未读取到引擎线程。")
                            } else {
                                LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                                    ForEach(appState.engineThreads.prefix(20)) { thread in
                                        Button {
                                            appState.selectedEngineThreadID = thread.id
                                            Task { await AppBootstrapper.loadEngineThreadDetail(appState: appState, threadID: thread.id) }
                                        } label: {
                                            selectableRow(
                                                title: thread.goal,
                                                subtitle: "\(thread.stepCount) 步 · \(thread.state)",
                                                isSelected: appState.selectedEngineThreadID == thread.id,
                                                trailing: thread.threadType
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        infoPanel(title: "引擎项目") {
                            if appState.engineProjects.isEmpty {
                                placeholderText("尚未读取到引擎项目。")
                            } else {
                                LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                                    ForEach(appState.engineProjects.prefix(20)) { project in
                                        selectableRow(
                                            title: project.name,
                                            subtitle: project.description,
                                            trailing: project.id
                                        )
                                    }
                                }
                            }
                        }
                    }
                } detail: {
                    if let mission = selectedMission {
                        MissionDetailPanel(appState: appState, mission: mission)
                    } else if let threadID = appState.selectedEngineThreadID {
                        EngineThreadDetailPanel(appState: appState, threadID: threadID)
                    } else {
                        detailCard(
                            title: "任务流详情",
                            lines: [("状态", "未选择任务流或线程"), ("二级内容", "步骤 / 事件 / 原始结构")],
                            description: "从左侧选择一个任务流或引擎线程后，这里会显示它的执行目标与二级内容。"
                        )
                    }
                }
            }
            .padding(ClawSpacing.md)
        }
        .background(ClawPalette.background)
    }

    private var selectedMission: EngineMissionInfo? {
        guard let selectedMissionID = appState.selectedMissionID else { return appState.missions.first }
        return appState.missions.first { $0.id == selectedMissionID } ?? appState.missions.first
    }
}

struct MissionDetailPanel: View {
    @Bindable var appState: AppState
    let mission: EngineMissionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            detailCard(
                title: mission.name,
                badge: mission.status,
                lines: [
                    ("任务流 ID", mission.id),
                    ("目标", mission.goal),
                    ("调度节奏", mission.cadenceDescription),
                    ("关联线程", "\(mission.threadCount)")
                ],
                description: "任务流详情已接入后端，可在下方查看原始结构与运行操作。"
            )

            HStack(spacing: ClawSpacing.sm) {
                Button("触发") {
                    Task { await AppBootstrapper.fireMission(appState: appState, missionID: mission.id) }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.success)

                Button("暂停") {
                    Task { await AppBootstrapper.pauseMission(appState: appState, missionID: mission.id) }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.warning)

                Button("恢复") {
                    Task { await AppBootstrapper.resumeMission(appState: appState, missionID: mission.id) }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.accent)
            }

            infoPanel(title: "任务流原始详情") {
                if let detail = appState.selectedMissionDetail {
                    Text(detail)
                        .font(.footnote.monospaced())
                        .foregroundStyle(ClawPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    placeholderText("正在读取任务流详情。")
                }
            }
        }
    }
}

struct EngineThreadDetailPanel: View {
    @Bindable var appState: AppState
    let threadID: String

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            detailCard(
                title: "引擎线程",
                badge: threadID,
                lines: [
                    ("线程 ID", threadID),
                    ("步骤数", "\(appState.engineThreadSteps.count)"),
                    ("事件数", "\(appState.engineThreadEvents.count)")
                ],
                description: "引擎线程的详细步骤与事件记录。"
            )

            if !appState.engineThreadSteps.isEmpty {
                infoPanel(title: "步骤") {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                        ForEach(appState.engineThreadSteps) { step in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("步骤 \(step.sequence)")
                                        .foregroundStyle(ClawPalette.textPrimary)
                                    Text("状态: \(step.status) · 层级: \(step.tier)")
                                        .font(.caption)
                                        .foregroundStyle(ClawPalette.textSecondary)
                                }
                                Spacer()
                                Text("\(step.tokensInput + step.tokensOutput) tokens")
                                    .font(.caption)
                                    .foregroundStyle(ClawPalette.textSecondary)
                            }
                            .padding(ClawSpacing.sm)
                            .background(ClawPalette.elevated.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }

            if !appState.engineThreadEvents.isEmpty {
                infoPanel(title: "事件") {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                        ForEach(appState.engineThreadEvents.indices, id: \.self) { index in
                            Text(appState.engineThreadEvents[index].prettyString)
                                .font(.caption.monospaced())
                                .foregroundStyle(ClawPalette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(ClawSpacing.sm)
                                .background(ClawPalette.elevated.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}