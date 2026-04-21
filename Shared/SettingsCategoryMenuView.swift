import SwiftUI

struct SettingsCategoryMenuView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Text("设置分区")
                .font(.headline)
                .foregroundStyle(ClawPalette.textPrimary)

            ForEach(SettingsCategory.allCases) { category in
                Button {
                    appState.selectedSettingsCategory = category
                } label: {
                    selectableRow(
                        title: category.rawValue,
                        subtitle: settingsSubtitle(for: category),
                        isSelected: appState.selectedSettingsCategory == category
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }

    private func settingsSubtitle(for category: SettingsCategory) -> String {
        switch category {
        case .inference: return "模型、后端与默认推理能力"
        case .agent: return "智能体行为、确认与执行策略"
        case .channels: return "聊天、SSE、WebSocket 通道状态"
        case .networking: return "网关地址、连接与健康状态"
        case .extensions: return "扩展入口与前端布局映射"
        case .mcp: return "MCP 服务连接与可用能力"
        case .skills: return "技能发现、调用与可见性"
        case .users: return "用户、角色与管理员能力"
        case .tools: return "工具调用权限与审批规则"
        }
    }
}
