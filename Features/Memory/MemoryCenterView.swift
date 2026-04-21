import SwiftUI

struct MemoryCenterView: View {
    @Bindable var appState: AppState
    @State private var isLoadingFile = false
    @State private var isSavingFile = false
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClawSpacing.md) {
                centerHeader(title: "记忆库", subtitle: "浏览目录、搜索内容、编辑文件，并在统一详情区完成保存。") {
                    Button("刷新") {
                        Task { await AppBootstrapper.refreshMemory(appState: appState) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClawPalette.accent)
                }

                infoPanel(title: "目录概览") {
                    LabeledValue(label: "条目数", value: "\(appState.memoryEntries.count)")
                    LabeledValue(label: "文件夹", value: "\(appState.memoryEntries.filter(\.isDir).count)")
                    LabeledValue(label: "文件", value: "\(appState.memoryEntries.filter { !$0.isDir }.count)")
                    LabeledValue(label: "当前文件", value: appState.selectedMemoryFile?.path ?? "未选择")
                }

                splitDetailShell {
                    VStack(alignment: .leading, spacing: ClawSpacing.md) {
                        infoPanel(title: "记忆搜索") {
                            TextField("输入关键词", text: $appState.memorySearchQuery)
                                .textFieldStyle(.roundedBorder)
                            Button(isSearching ? "搜索中..." : "搜索") {
                                Task { await searchMemory() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ClawPalette.accent)
                            .disabled(isSearching || appState.memorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            if !appState.memorySearchResults.isEmpty {
                                ForEach(appState.memorySearchResults.prefix(10)) { hit in
                                    Button {
                                        appState.selectedMemoryPath = hit.path
                                        Task { await loadMemoryFile(path: hit.path) }
                                    } label: {
                                        selectableRow(
                                            title: hit.path.components(separatedBy: "/").last ?? hit.path,
                                            subtitle: hit.path,
                                            isSelected: appState.selectedMemoryPath == hit.path,
                                            trailing: String(format: "%.2f", hit.score)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        infoPanel(title: "文件列表") {
                            if appState.memoryEntries.isEmpty {
                                placeholderText("尚未读取到记忆条目。")
                            } else {
                                ForEach(appState.memoryEntries.prefix(40)) { entry in
                                    Button {
                                        guard !entry.isDir else { return }
                                        appState.selectedMemoryPath = entry.path
                                        Task { await loadMemoryFile(path: entry.path) }
                                    } label: {
                                        selectableRow(
                                            title: entry.name,
                                            subtitle: entry.path,
                                            isSelected: appState.selectedMemoryPath == entry.path,
                                            trailing: entry.isDir ? "目录" : "文件",
                                            tint: entry.isDir ? ClawPalette.warning : ClawPalette.accent
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(entry.isDir)
                                }
                            }
                        }
                    }
                } detail: {
                    if isLoadingFile {
                        detailCard(
                            title: "正在读取",
                            lines: [("状态", "加载中"), ("路径", appState.selectedMemoryPath ?? "未选择")],
                            description: "正在从网关读取记忆文件内容。"
                        )
                    } else if let file = appState.selectedMemoryFile {
                        VStack(alignment: .leading, spacing: ClawSpacing.md) {
                            detailCard(
                                title: file.path.components(separatedBy: "/").last ?? file.path,
                                badge: "记忆文件",
                                lines: [
                                    ("完整路径", file.path),
                                    ("更新时间", file.updatedAt ?? "未知"),
                                    ("字符数", "\(appState.memoryEditorContent.count)")
                                ],
                                description: "这里可以直接编辑并保存记忆文件，搜索结果也统一回到这个详情区。"
                            )

                            infoPanel(title: "文件编辑") {
                                TextEditor(text: $appState.memoryEditorContent)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(ClawPalette.textPrimary)
                                    .frame(minHeight: 320)
                                    .padding(ClawSpacing.sm)
                                    .background(ClawPalette.elevated.opacity(0.75))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                HStack(spacing: ClawSpacing.sm) {
                                    Button(isSavingFile ? "保存中..." : "保存") {
                                        Task { await saveMemoryFile(path: file.path) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(ClawPalette.success)
                                    .disabled(isSavingFile)

                                    Button("重新读取") {
                                        Task { await loadMemoryFile(path: file.path) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    } else {
                        detailCard(
                            title: "文件详情",
                            lines: [("状态", "未选择文件"), ("支持操作", "阅读 / 编辑 / 搜索")],
                            description: "从左侧选择一个记忆文件后，这里会显示详情、正文与后续操作。"
                        )
                    }
                }
            }
            .padding(ClawSpacing.md)
        }
        .background(ClawPalette.background)
    }

    private func loadMemoryFile(path: String) async {
        isLoadingFile = true
        defer { isLoadingFile = false }
        await AppBootstrapper.readMemoryFile(appState: appState, path: path)
    }

    private func saveMemoryFile(path: String) async {
        isSavingFile = true
        defer { isSavingFile = false }
        await AppBootstrapper.writeMemoryFile(appState: appState, path: path, content: appState.memoryEditorContent)
    }

    private func searchMemory() async {
        isSearching = true
        defer { isSearching = false }
        await AppBootstrapper.searchMemory(appState: appState)
    }
}
