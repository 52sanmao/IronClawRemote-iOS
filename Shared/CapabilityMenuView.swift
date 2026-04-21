import SwiftUI

struct CapabilityMenuView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Text("能力入口")
                .font(.headline)
                .foregroundStyle(ClawPalette.textPrimary)

            ForEach(CapabilityCategory.allCases) { category in
                Button {
                    appState.selectedCapabilityCategory = category
                } label: {
                    selectableRow(
                        title: category.rawValue,
                        subtitle: capabilitySubtitle(for: category),
                        isSelected: appState.selectedCapabilityCategory == category
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }

    private func capabilitySubtitle(for category: CapabilityCategory) -> String {
        switch category {
        case .extensions: return "管理扩展入口与布局显示"
        case .skills: return "查看技能能力、说明与调用方式"
        case .mcp: return "查看 MCP 服务、连接和能力暴露"
        }
    }
}
