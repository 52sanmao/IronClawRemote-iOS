import SwiftUI

struct JobsCenterView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClawSpacing.md) {
                centerHeader(title: "任务中心", subtitle: "集中查看任务列表、详情、后续动作和事件入口。") {
                    Button("刷新") {
                        Task { await AppBootstrapper.refreshJobs(appState: appState) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClawPalette.accent)
                }

                infoPanel(title: "任务摘要") {
                    LabeledValue(label: "总数", value: "\(appState.jobSummary?.total ?? 0)")
                    LabeledValue(label: "等待中", value: "\(appState.jobSummary?.pending ?? 0)")
                    LabeledValue(label: "进行中", value: "\(appState.jobSummary?.inProgress ?? 0)")
                    LabeledValue(label: "已完成", value: "\(appState.jobSummary?.completed ?? 0)")
                    LabeledValue(label: "失败", value: "\(appState.jobSummary?.failed ?? 0)")
                }

                splitDetailShell {
                    infoPanel(title: "最近任务") {
                        if appState.jobs.isEmpty {
                            placeholderText("当前没有任务记录。")
                        } else {
                            ForEach(appState.jobs.prefix(30)) { job in
                                Button {
                                    appState.selectedJobID = job.id
                                    appState.selectedJobDetail = nil
                                    appState.selectedJobEvents = []
                                    appState.selectedJobFileEntries = []
                                    appState.selectedJobFilePath = nil
                                    appState.selectedJobFileContent = nil
                                    Task { await AppBootstrapper.loadJobDetail(appState: appState, jobID: job.id) }
                                } label: {
                                    selectableRow(
                                        title: job.title,
                                        subtitle: job.id.uuidString,
                                        isSelected: appState.selectedJobID == job.id,
                                        trailing: job.state
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } detail: {
                    if let jobID = appState.selectedJobID, let detail = selectedJobDetail, detail.id == jobID {
                        VStack(alignment: .leading, spacing: ClawSpacing.md) {
                            detailCard(
                                title: detail.title,
                                badge: detail.state,
                                lines: [
                                    ("任务 ID", detail.id.uuidString),
                                    ("描述", detail.description),
                                    ("用户", detail.userId),
                                    ("创建时间", detail.createdAt),
                                    ("开始时间", detail.startedAt ?? "未开始"),
                                    ("完成时间", detail.completedAt ?? "未完成"),
                                    ("耗时", detail.elapsedSecs.map { "\($0) 秒" } ?? "未知"),
                                    ("工作目录", detail.projectDir ?? "无"),
                                    ("任务模式", detail.jobMode ?? "未知"),
                                    ("任务类型", detail.jobKind ?? "未知")
                                ],
                                description: detail.browseURL.map { "浏览地址：\($0)" }
                            )

                            infoPanel(title: "状态转换") {
                                if detail.transitions.isEmpty {
                                    placeholderText("暂无状态转换记录。")
                                } else {
                                    ForEach(detail.transitions.prefix(10)) { transition in
                                        LabeledValue(label: "\(transition.from) → \(transition.to)", value: transition.reason ?? transition.timestamp)
                                    }
                                }
                            }

                            infoPanel(title: "事件流") {
                                if appState.selectedJobEvents.isEmpty {
                                    placeholderText("暂无事件记录。")
                                } else {
                                    ForEach(appState.selectedJobEvents.prefix(15)) { event in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(event.eventType)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(ClawPalette.accent)
                                            Text(event.createdAt)
                                                .font(.caption2)
                                                .foregroundStyle(ClawPalette.textSecondary)
                                            Text(event.data.shortString)
                                                .font(.footnote)
                                                .foregroundStyle(ClawPalette.textPrimary)
                                                .lineLimit(3)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                    }
                                }
                            }

                            infoPanel(title: "产物文件") {
                                if appState.selectedJobFileEntries.isEmpty {
                                    placeholderText("暂无文件。")
                                } else {
                                    ForEach(appState.selectedJobFileEntries.prefix(20)) { entry in
                                        Button {
                                            guard !entry.isDir else { return }
                                            Task { await AppBootstrapper.loadJobFile(appState: appState, jobID: jobID, path: entry.path) }
                                        } label: {
                                            selectableRow(
                                                title: entry.name,
                                                subtitle: entry.path,
                                                isSelected: appState.selectedJobFilePath == entry.path,
                                                trailing: entry.isDir ? "目录" : "文件",
                                                tint: entry.isDir ? ClawPalette.warning : ClawPalette.accent
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(entry.isDir)
                                    }
                                }
                            }

                            if let fileContent = appState.selectedJobFileContent {
                                infoPanel(title: "文件内容：\(fileContent.path)") {
                                    Text(fileContent.content)
                                        .font(.footnote.monospaced())
                                        .foregroundStyle(ClawPalette.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .padding(ClawSpacing.md)
                                        .background(ClawPalette.elevated.opacity(0.75))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }

                            HStack(spacing: ClawSpacing.sm) {
                                if detail.canRestart {
                                    Button("重启任务") {
                                        Task { await AppBootstrapper.restartJob(appState: appState, jobID: jobID) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(ClawPalette.success)
                                }

                                Button("取消任务") {
                                    Task { await AppBootstrapper.cancelJob(appState: appState, jobID: jobID) }
                                }
                                .buttonStyle(.bordered)
                                .tint(ClawPalette.warning)
                            }

                            if detail.canPrompt {
                                infoPanel(title: "跟进提问") {
                                    TextField("输入跟进提示", text: $appState.jobPromptDraft, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(3...6)
                                    Button("发送") {
                                        Task { await AppBootstrapper.sendJobPrompt(appState: appState, jobID: jobID) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(ClawPalette.accent)
                                    .disabled(appState.jobPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                        }
                    } else if let jobID = appState.selectedJobID {
                        detailCard(
                            title: "正在加载",
                            lines: [("任务 ID", jobID.uuidString)],
                            description: "正在从网关读取任务详情。"
                        )
                    } else {
                        detailCard(
                            title: "任务详情",
                            lines: [("状态", "未选择任务"), ("二级内容", "详情 / 事件 / 文件")],
                            description: "从左侧选择一个任务后，这里会显示完整二级内容。"
                        )
                    }
                }
            }
            .padding(ClawSpacing.md)
        }
        .background(ClawPalette.background)
    }

    private var selectedJobDetail: JobDetailResponse? {
        guard let jobID = appState.selectedJobID else { return nil }
        guard let detail = appState.selectedJobDetail, detail.id == jobID else { return nil }
        return detail
    }
}
