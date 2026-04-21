import Foundation

enum IronSection: String, CaseIterable, Identifiable {
    case chat
    case memory
    case jobs
    case missions
    case routines
    case capabilities
    case system
    case logs

    var id: String { rawValue }
}

enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
    case assistant = "助手会话"
    case conversations = "全部会话"
    case newConversation = "新建会话"
    case memory = "记忆库"
    case jobs = "任务中心"
    case missions = "任务流"
    case routines = "定时器"
    case extensions = "扩展中心"
    case skills = "技能库"
    case mcp = "MCP 服务"
    case settings = "系统设置"
    case logs = "运行日志"
    case account = "账号与安全"

    var id: String { rawValue }
}

enum AppPane: String, CaseIterable, Identifiable {
    case chat = "聊天"
    case memory = "记忆库"
    case jobs = "任务中心"
    case missions = "任务流"
    case routines = "定时器"
    case extensions = "扩展中心"
    case skills = "技能库"
    case mcp = "MCP 服务"
    case settings = "系统设置"
    case logs = "运行日志"
    case account = "账号与安全"

    var id: String { rawValue }
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case inference = "推理引擎"
    case agent = "代理行为"
    case channels = "连接通道"
    case networking = "网络与网关"
    case extensions = "扩展中心"
    case mcp = "MCP 服务"
    case skills = "技能库"
    case users = "用户管理"
    case tools = "工具权限"

    var id: String { rawValue }
}

enum CapabilityCategory: String, CaseIterable, Identifiable {
    case extensions = "扩展中心"
    case skills = "技能库"
    case mcp = "MCP 服务"

    var id: String { rawValue }
}

struct SidebarGroup: Identifiable {
    let id = UUID()
    let title: String
    let items: [SidebarDestination]
}
