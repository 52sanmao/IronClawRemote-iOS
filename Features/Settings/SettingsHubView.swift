import SwiftUI

struct SettingsHubView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClawSpacing.md) {
                centerHeader(title: currentTitle, subtitle: currentSubtitle) {
                    HStack(spacing: ClawSpacing.sm) {
                        Button("刷新网关") {
                            Task {
                                await AppBootstrapper.refreshGatewayStatus(appState: appState)
                                await AppBootstrapper.refreshProviders(appState: appState)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ClawPalette.accent)

                        if appState.currentPane == .settings || appState.currentPane == .extensions || appState.currentPane == .skills || appState.currentPane == .mcp {
                            Button("刷新配置") {
                                Task {
                                    await AppBootstrapper.refreshSettings(appState: appState)
                                    await AppBootstrapper.refreshToolPermissions(appState: appState)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(ClawPalette.accent)
                        }
                    }
                }

                switch appState.currentPane {
                case .extensions, .skills, .mcp:
                    capabilityContent
                default:
                    settingsContent
                }
            }
            .padding(ClawSpacing.md)
        }
        .background(ClawPalette.background)
        .task {
            await AppBootstrapper.refreshSettings(appState: appState)
            await AppBootstrapper.refreshToolPermissions(appState: appState)
        }
    }

    private var capabilityContent: some View {
        splitDetailShell {
            CapabilityMenuView(appState: appState)
        } detail: {
            capabilityDetail
        }
    }

    private var capabilityDetail: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            detailCard(
                title: appState.selectedCapabilityCategory.rawValue,
                badge: "能力模块",
                lines: capabilityLines,
                description: capabilityDescription,
                footer: "一级入口仅保留左侧「能力」三项；具体内容统一在这里下钻，不再在其他页面重复出现。"
            )

            if appState.selectedCapabilityCategory == .extensions {
                ExtensionsCapabilityPanel(appState: appState)
            } else if appState.selectedCapabilityCategory == .skills {
                SkillsCapabilityPanel(appState: appState)
            } else if appState.selectedCapabilityCategory == .mcp {
                infoPanel(title: "MCP 服务") {
                    placeholderText("MCP 服务列表待接入")
                }
            }
        }
        .task {
            if appState.selectedCapabilityCategory == .extensions {
                await AppBootstrapper.refreshExtensions(appState: appState)
                await AppBootstrapper.refreshRegistry(appState: appState)
            } else if appState.selectedCapabilityCategory == .skills {
                await AppBootstrapper.refreshSkills(appState: appState)
            }
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            infoPanel(title: "当前模块") {
                LabeledValue(label: "页面", value: appState.currentPane.rawValue)
                LabeledValue(label: "模型", value: appState.gatewayStatus?.llmModel ?? "未获取")
                LabeledValue(label: "后端", value: appState.gatewayStatus?.llmBackend ?? "未获取")
            }

            splitDetailShell {
                SettingsCategoryMenuView(appState: appState)
            } detail: {
                VStack(alignment: .leading, spacing: ClawSpacing.md) {
                    if appState.selectedSettingsCategory == .tools {
                        toolsPermissionPanel
                    } else {
                        settingsKeysPanel
                    }
                }
            }
        }
    }

    private var settingsKeysPanel: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            detailCard(
                title: appState.selectedSettingsCategory.rawValue,
                badge: "设置分区",
                lines: settingsLines,
                description: settingsDescription,
                footer: "系统设置只保留一个一级入口；所有二级配置都在这里统一归档。"
            )

            if appState.selectedSettingsCategory == .inference || appState.selectedSettingsCategory == .networking {
                providersPanel
            }

            settingsKeysList
        }
    }

    private var settingsKeysList: some View {
        infoPanel(title: "配置项") {
            let keys = relevantSettingKeys
            if keys.isEmpty {
                placeholderText("暂无相关配置项")
            } else {
                LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                    ForEach(keys, id: \.self) { key in
                        Button {
                            appState.selectedSettingKey = key
                        } label: {
                            selectableRow(
                                title: key,
                                subtitle: appState.settingsMap[key]?.shortString ?? "",
                                isSelected: appState.selectedSettingKey == key
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selectedKey = appState.selectedSettingKey, let value = appState.settingsMap[selectedKey] {
                SettingEditorCard(appState: appState, settingKey: selectedKey, value: value)
            }
        }
    }

    private var toolsPermissionPanel: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            detailCard(
                title: "工具权限",
                badge: "设置分区",
                lines: [
                    ("工具总数", "\(appState.toolPermissions.count)"),
                    ("已锁定", "\(appState.toolPermissions.filter(\.locked).count)"),
                    ("可配置", "\(appState.toolPermissions.filter { !$0.locked }.count)")
                ],
                description: "管理每个工具的调用权限：始终允许、每次询问或禁用。",
                footer: "锁定的工具因风险等级过高，无法修改权限。"
            )

            infoPanel(title: "工具列表") {
                if appState.toolPermissions.isEmpty {
                    placeholderText("尚未读取工具权限列表")
                } else {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                        ForEach(appState.toolPermissions) { tool in
                            ToolPermissionRow(appState: appState, tool: tool)
                        }
                    }
                }
            }
        }
    }

    private var providersPanel: some View {
        infoPanel(title: "可用提供商") {
            if appState.providers.isEmpty {
                placeholderText("尚未读取到模型提供商。")
            } else {
                ForEach(appState.providers.prefix(20)) { provider in
                    selectableRow(
                        title: provider.name,
                        subtitle: provider.adapter,
                        trailing: provider.defaultModel ?? "未设默认模型"
                    )
                }
            }
        }
    }

    private var relevantSettingKeys: [String] {
        switch appState.selectedSettingsCategory {
        case .tools:
            return appState.settingsMap.keys.filter { $0.hasPrefix("tool_permissions") }.sorted()
        default:
            return appState.settingsMap.keys.sorted()
        }
    }

    private var currentTitle: String {
        switch appState.currentPane {
        case .extensions, .skills, .mcp:
            return "能力中心"
        default:
            return "系统设置"
        }
    }

    private var currentSubtitle: String {
        switch appState.currentPane {
        case .extensions, .skills, .mcp:
            return "统一承载扩展、技能与 MCP 服务的能力详情，避免入口重复。"
        default:
            return "统一承载推理引擎、代理行为、通道、网络和管理配置。"
        }
    }

    private var capabilityLines: [(String, String)] {
        switch appState.selectedCapabilityCategory {
        case .extensions:
            return [
                ("显示位置", "能力区 > 扩展中心"),
                ("当前状态", "已接入 /api/extensions"),
                ("二级内容", "扩展详情 / 开关 / 布局映射")
            ]
        case .skills:
            return [
                ("显示位置", "能力区 > 技能库"),
                ("当前状态", "已接入 /api/skills"),
                ("二级内容", "技能详情 / 说明 / 调用入口")
            ]
        case .mcp:
            return [
                ("显示位置", "能力区 > MCP 服务"),
                ("当前状态", "MCP 服务列表待接入"),
                ("二级内容", "服务详情 / 工具暴露 / 连接状态")
            ]
        }
    }

    private var capabilityDescription: String {
        switch appState.selectedCapabilityCategory {
        case .extensions:
            return "这里会展示 web 端 frontend layout/widgets 对应的移动端能力入口与显隐状态。"
        case .skills:
            return "这里会承载技能的说明、是否可见、可用命令与调用统计。"
        case .mcp:
            return "这里会承载 MCP 服务连接状态、暴露工具和调用能力。"
        }
    }

    private var settingsLines: [(String, String)] {
        switch appState.selectedSettingsCategory {
        case .inference:
            return [
                ("当前模型", appState.gatewayStatus?.llmModel ?? "未获取"),
                ("推理后端", appState.gatewayStatus?.llmBackend ?? "未获取"),
                ("相关配置", "\(relevantSettingKeys.count) 项")
            ]
        case .agent:
            return [
                ("当前状态", "已接入设置读写"),
                ("相关配置", "\(relevantSettingKeys.count) 项"),
                ("入口策略", "仅在系统设置中出现")
            ]
        case .channels:
            return [
                ("SSE 连接", "\(appState.gatewayStatus?.sseConnections ?? 0)"),
                ("WS 连接", "\(appState.gatewayStatus?.wsConnections ?? 0)"),
                ("相关配置", "\(relevantSettingKeys.count) 项")
            ]
        case .networking:
            return [
                ("网关地址", appState.baseURLString),
                ("总连接", "\(appState.gatewayStatus?.totalConnections ?? 0)"),
                ("相关配置", "\(relevantSettingKeys.count) 项")
            ]
        case .extensions:
            return [
                ("说明", "扩展管理已归并到能力中心"),
                ("这里只保留", "策略与权限"),
                ("相关配置", "\(relevantSettingKeys.count) 项")
            ]
        case .mcp:
            return [
                ("说明", "MCP 连接详情已归并到能力中心"),
                ("这里只保留", "接入策略与默认行为"),
                ("相关配置", "\(relevantSettingKeys.count) 项")
            ]
        case .skills:
            return [
                ("说明", "技能详情已归并到能力中心"),
                ("这里只保留", "技能可见性与规则"),
                ("相关配置", "\(relevantSettingKeys.count) 项")
            ]
        case .users:
            return [
                ("当前角色", appState.profile?.role ?? "未知"),
                ("当前用户", appState.profile?.displayName ?? "未获取"),
                ("相关配置", "\(relevantSettingKeys.count) 项")
            ]
        case .tools:
            return [
                ("当前状态", appState.pendingGate == nil ? "无待确认" : "有待确认"),
                ("工具总数", "\(appState.toolPermissions.count)"),
                ("入口策略", "统一收纳在设置中")
            ]
        }
    }

    private var settingsDescription: String {
        switch appState.selectedSettingsCategory {
        case .inference:
            return "这里对应 web 端推理配置能力，支持读取和修改模型、默认提供商与推理参数。"
        case .agent:
            return "这里对应智能体行为配置，支持读取和修改自动执行、确认策略和默认风格。"
        case .channels:
            return "这里统一展示聊天、日志等通道状态与配置。"
        case .networking:
            return "这里负责网关地址、连接状态、版本与连接测试相关配置。"
        case .extensions:
            return "扩展的实体详情放在能力中心，这里只保留策略配置。"
        case .mcp:
            return "MCP 的实体详情放在能力中心，这里只保留接入规则和默认行为。"
        case .skills:
            return "技能的实体详情放在能力中心，这里只保留管理规则。"
        case .users:
            return "这里会承载管理员用户管理能力。"
        case .tools:
            return "这里会承载工具权限与审批策略。"
        }
    }
}

struct SettingEditorCard: View {
    @Bindable var appState: AppState
    let settingKey: String
    let value: JSONValue

    @State private var editorText: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            HStack {
                Text(settingKey)
                    .font(.headline)
                    .foregroundStyle(ClawPalette.textPrimary)
                Spacer()
                Text(valueTypeLabel)
                    .font(.caption)
                    .foregroundStyle(ClawPalette.textSecondary)
            }

            TextEditor(text: $editorText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .padding(ClawSpacing.sm)
                .background(ClawPalette.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Button("删除") {
                    Task {
                        await AppBootstrapper.deleteSetting(appState: appState, key: settingKey)
                    }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.danger)

                Spacer()

                Button("保存") {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        if let newValue = parseEditorText() {
                            await AppBootstrapper.setSetting(appState: appState, key: settingKey, value: newValue)
                        } else {
                            appState.statusText = "JSON 格式错误，无法保存"
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.accent)
                .disabled(isSaving)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
        .onAppear {
            editorText = value.prettyString
        }
    }

    private var valueTypeLabel: String {
        switch value {
        case .string: return "字符串"
        case .number: return "数值"
        case .bool: return "布尔"
        case .object: return "对象"
        case .array: return "数组"
        case .null: return "空值"
        }
    }

    private func parseEditorText() -> JSONValue? {
        guard let data = editorText.data(using: .utf8) else { return nil }
        if let decoded = try? JSONDecoder().decode(JSONValue.self, from: data) {
            return decoded
        }
        if let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if string == "true" { return .bool(true) }
            if string == "false" { return .bool(false) }
            if string == "null" { return .null }
            if let number = Double(string) { return .number(number) }
            return .string(string)
        }
        return nil
    }
}

struct ExtensionsCapabilityPanel: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            infoPanel(title: "已安装扩展") {
                if appState.extensions.isEmpty {
                    placeholderText("尚未安装任何扩展")
                } else {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                        ForEach(appState.extensions) { ext in
                            Button {
                                appState.selectedExtensionName = ext.name
                            } label: {
                                selectableRow(
                                    title: ext.displayName ?? ext.name,
                                    subtitle: ext.kind,
                                    isSelected: appState.selectedExtensionName == ext.name,
                                    trailing: ext.active ? "已激活" : (ext.authenticated ? "已配置" : "已安装")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            infoPanel(title: "扩展仓库") {
                if appState.registryEntries.isEmpty {
                    placeholderText("尚未读取扩展仓库")
                } else {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                        ForEach(appState.registryEntries.filter { !$0.installed }) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.displayName)
                                        .foregroundStyle(ClawPalette.textPrimary)
                                    Text(entry.description)
                                        .font(.caption)
                                        .foregroundStyle(ClawPalette.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button("安装") {
                                    Task {
                                        await AppBootstrapper.installExtension(appState: appState, name: entry.name)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(ClawPalette.accent)
                                .controlSize(.small)
                            }
                            .padding(ClawSpacing.sm)
                            .background(ClawPalette.elevated.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }

            if let selectedName = appState.selectedExtensionName,
               let ext = appState.extensions.first(where: { $0.name == selectedName }) {
                ExtensionDetailCard(appState: appState, ext: ext)
            }
        }
    }
}

struct ExtensionDetailCard: View {
    @Bindable var appState: AppState
    let ext: ExtensionInfo

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            HStack {
                Text(ext.displayName ?? ext.name)
                    .font(.headline)
                    .foregroundStyle(ClawPalette.textPrimary)
                Spacer()
                Text(ext.activationStatus?.rawValue ?? "unknown")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ext.active ? ClawPalette.accentSoft : ClawPalette.elevated)
                    .foregroundStyle(ext.active ? ClawPalette.accent : ClawPalette.textSecondary)
                    .clipShape(Capsule())
            }

            if let desc = ext.description, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .foregroundStyle(ClawPalette.textPrimary)
            }

            HStack(spacing: ClawSpacing.sm) {
                if !ext.active {
                    Button("激活") {
                        Task {
                            await AppBootstrapper.activateExtension(appState: appState, name: ext.name)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClawPalette.accent)
                }
                Button("移除") {
                    Task {
                        await AppBootstrapper.removeExtension(appState: appState, name: ext.name)
                    }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.danger)
            }

            if !ext.tools.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("提供工具")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ClawPalette.textSecondary)
                    Text(ext.tools.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(ClawPalette.textPrimary)
                }
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }
}

struct SkillsCapabilityPanel: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            HStack(spacing: ClawSpacing.sm) {
                TextField("搜索技能...", text: $appState.skillSearchQuery)
                    .textFieldStyle(.roundedBorder)
                Button("搜索") {
                    Task {
                        await AppBootstrapper.searchSkills(appState: appState)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.accent)
            }

            infoPanel(title: "已安装技能") {
                if appState.skills.isEmpty {
                    placeholderText("尚未安装任何技能")
                } else {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                        ForEach(appState.skills) { skill in
                            Button {
                                appState.selectedSkillName = skill.name
                            } label: {
                                selectableRow(
                                    title: skill.name,
                                    subtitle: skill.description,
                                    isSelected: appState.selectedSkillName == skill.name,
                                    trailing: skill.trust
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !appState.skillSearchResults.isEmpty {
                infoPanel(title: "搜索结果") {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                        ForEach(appState.skillSearchResults.indices, id: \.self) { index in
                            let result = appState.skillSearchResults[index]
                            SkillSearchResultRow(appState: appState, result: result)
                        }
                    }
                }
            }

            if let selectedName = appState.selectedSkillName,
               let skill = appState.skills.first(where: { $0.name == selectedName }) {
                SkillDetailCard(appState: appState, skill: skill)
            }
        }
    }
}

struct SkillSearchResultRow: View {
    @Bindable var appState: AppState
    let result: JSONValue

    private var name: String {
        if case .object(let dict) = result, case .string(let val) = dict["name"] { return val }
        return "未知"
    }

    private var slug: String? {
        if case .object(let dict) = result, case .string(let val) = dict["slug"] { return val }
        return nil
    }

    private var description: String {
        if case .object(let dict) = result, case .string(let val) = dict["description"] { return val }
        return ""
    }

    private var installed: Bool {
        if case .object(let dict) = result, case .bool(let val) = dict["installed"] { return val }
        return false
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundStyle(ClawPalette.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(ClawPalette.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if installed {
                Text("已安装")
                    .font(.caption)
                    .foregroundStyle(ClawPalette.textSecondary)
            } else {
                Button("安装") {
                    Task {
                        await AppBootstrapper.installSkill(appState: appState, name: name, slug: slug)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.accent)
                .controlSize(.small)
            }
        }
        .padding(ClawSpacing.sm)
        .background(ClawPalette.elevated.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SkillDetailCard: View {
    @Bindable var appState: AppState
    let skill: SkillInfo

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            HStack {
                Text(skill.name)
                    .font(.headline)
                    .foregroundStyle(ClawPalette.textPrimary)
                Spacer()
                Text(skill.trust)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ClawPalette.accentSoft)
                    .foregroundStyle(ClawPalette.accent)
                    .clipShape(Capsule())
            }

            if !skill.description.isEmpty {
                Text(skill.description)
                    .font(.body)
                    .foregroundStyle(ClawPalette.textPrimary)
            }

            if !skill.keywords.isEmpty {
                Text("关键词: \(skill.keywords.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(ClawPalette.textSecondary)
            }

            HStack {
                Button("移除") {
                    Task {
                        await AppBootstrapper.removeSkill(appState: appState, name: skill.name)
                    }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.danger)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }
}

struct ToolPermissionRow: View {
    @Bindable var appState: AppState
    let tool: ToolPermissionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .foregroundStyle(ClawPalette.textPrimary)
                    if !tool.description.isEmpty {
                        Text(tool.description)
                            .font(.caption)
                            .foregroundStyle(ClawPalette.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if tool.locked {
                    Text("已锁定")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ClawPalette.danger.opacity(0.15))
                        .foregroundStyle(ClawPalette.danger)
                        .clipShape(Capsule())
                }
            }

            if !tool.locked {
                HStack(spacing: ClawSpacing.sm) {
                    ForEach([("always_allow", "始终允许"), ("ask_each_time", "每次询问"), ("disabled", "禁用")], id: \.0) { state, label in
                        Button {
                            Task {
                                await AppBootstrapper.updateToolPermission(appState: appState, toolName: tool.name, state: state)
                            }
                        } label: {
                            Text(label)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(tool.currentState == state ? ClawPalette.accentSoft : ClawPalette.elevated)
                                .foregroundStyle(tool.currentState == state ? ClawPalette.accent : ClawPalette.textPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let reason = tool.lockedReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(ClawPalette.textSecondary)
            }
        }
        .padding(ClawSpacing.sm)
        .background(ClawPalette.elevated.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}