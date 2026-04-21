import Foundation
import Observation

@Observable
final class AppState {
    var baseURLString: String = "https://rare-lark.agent4.near.ai"
    var token: String = TokenStore.shared.load() ?? ""
    var isAuthenticated: Bool = !(TokenStore.shared.load() ?? "").isEmpty

    var selectedDestination: SidebarDestination = .assistant
    var currentPane: AppPane = .chat

    var selectedMemoryPath: String?
    var selectedJobID: UUID?
    var selectedMissionID: String?
    var selectedRoutineID: UUID?
    var selectedSettingsCategory: SettingsCategory = .inference
    var selectedCapabilityCategory: CapabilityCategory = .extensions

    var profile: ProfileResponse?
    var gatewayStatus: GatewayStatusResponse?

    var assistantThread: ThreadInfo?
    var threads: [ThreadInfo] = []
    var currentThreadID: UUID?
    var turns: [TurnInfo] = []
    var pendingGate: PendingGateInfo?
    var pendingApproval: ApprovalNeededEvent?
    var pendingAuth: AuthRequiredEvent?
    var draftMessage: String = ""
    var streamingText: String = ""
    var statusText: String = "就绪"
    var inspectorEvents: [String] = []
    var draftImages: [ImagePayload] = []

    var memoryEntries: [MemoryListEntry] = []
    var selectedMemoryFile: MemoryReadResponse?
    var memoryEditorContent: String = ""
    var memorySearchQuery: String = ""
    var memorySearchResults: [MemorySearchHit] = []
    var jobs: [JobInfo] = []
    var jobSummary: JobSummaryResponse?
    var selectedJobDetail: JobDetailResponse?
    var selectedJobEvents: [JobEventInfo] = []
    var selectedJobFileEntries: [ProjectFileEntry] = []
    var selectedJobFileContent: ProjectFileReadResponse?
    var selectedJobFilePath: String?
    var jobPromptDraft: String = ""
    var routines: [RoutineInfo] = []
    var routineSummary: RoutineSummaryResponse?
    var selectedRoutineDetail: RoutineDetailResponse?
    var routineRuns: [RoutineRunInfo] = []
    var missions: [EngineMissionInfo] = []
    var selectedMissionDetail: String?
    var missionSummary: EngineMissionSummaryResponse?

    var engineThreads: [EngineThreadInfo] = []
    var selectedEngineThreadID: String?
    var engineThreadSteps: [EngineStepInfo] = []
    var engineThreadEvents: [JSONValue] = []
    var engineProjects: [EngineProjectInfo] = []

    var tokens: [TokenInfo] = []
    var createdTokenPlaintext: String?

    var adminUsers: [AdminUserInfo] = []
    var selectedAdminUserID: String?
    var isAdmin: Bool { profile?.role == "admin" }
    var providers: [LLMProviderInfo] = []
    var logLevel: String = "INFO"
    var logEntries: [LogEntry] = []
    var selectedLogEntryID: String?

    var settingsMap: [String: JSONValue] = [:]
    var toolPermissions: [ToolPermissionEntry] = []
    var selectedSettingKey: String?

    var extensions: [ExtensionInfo] = []
    var registryEntries: [RegistryEntryInfo] = []
    var selectedExtensionName: String?
    var extensionSetup: ExtensionSetupResponse?

    var skills: [SkillInfo] = []
    var skillSearchResults: [JSONValue] = []
    var skillSearchQuery: String = ""
    var selectedSkillName: String?

    let chatSSE = SSEClient()
    let logsSSE = SSEClient()

    init() {
        configureSSE()
        if isAuthenticated {
            configureClient()
        }
    }

    var sidebarGroups: [SidebarGroup] {
        [
            SidebarGroup(title: "对话", items: [.assistant, .conversations, .newConversation]),
            SidebarGroup(title: "空间", items: [.memory, .jobs, .missions, .routines]),
            SidebarGroup(title: "能力", items: [.extensions, .skills, .mcp]),
            SidebarGroup(title: "系统", items: [.settings, .logs, .account])
        ]
    }

    func configureClient() {
        guard let url = URL(string: baseURLString), !token.isEmpty else { return }
        APIClient.shared.configure(baseURL: url, token: token)
    }

    func login() {
        TokenStore.shared.save(token)
        isAuthenticated = true
        configureClient()
    }

    func logout() {
        TokenStore.shared.clear()
        token = ""
        isAuthenticated = false
        profile = nil
        threads = []
        turns = []
        currentThreadID = nil
        chatSSE.disconnect()
        logsSSE.disconnect()
    }

    func select(_ destination: SidebarDestination) {
        selectedDestination = destination
        switch destination {
        case .assistant:
            currentPane = .chat
            currentThreadID = assistantThread?.id ?? currentThreadID
        case .conversations:
            currentPane = .chat
            if currentThreadID == nil {
                currentThreadID = threads.first?.id ?? assistantThread?.id
            }
        case .newConversation:
            currentPane = .chat
            currentThreadID = nil
            turns = []
            streamingText = ""
            pendingGate = nil
            pendingApproval = nil
            pendingAuth = nil
            draftImages = []
            statusText = "准备开始新会话"
        case .memory:
            currentPane = .memory
        case .jobs:
            currentPane = .jobs
        case .missions:
            currentPane = .missions
        case .routines:
            currentPane = .routines
        case .extensions:
            currentPane = .extensions
            selectedCapabilityCategory = .extensions
        case .skills:
            currentPane = .skills
            selectedCapabilityCategory = .skills
        case .mcp:
            currentPane = .mcp
            selectedCapabilityCategory = .mcp
        case .settings:
            currentPane = .settings
        case .logs:
            currentPane = .logs
        case .account:
            currentPane = .account
        }
    }

    func configureSSE() {
        chatSSE.onEvent = { [weak self] payload in
            guard let self else { return }
            switch payload {
            case .response(let event):
                if let content = event.content {
                    self.streamingText = content
                    self.statusText = "已收到回复"
                    self.inspectorEvents.insert("已收到最终回复", at: 0)
                }
                if let threadIDString = event.threadId, let threadID = UUID(uuidString: threadIDString) {
                    self.currentThreadID = threadID
                    Task { await AppBootstrapper.refreshHistory(appState: self, threadID: threadID) }
                } else if let threadID = self.currentThreadID {
                    Task { await AppBootstrapper.refreshHistory(appState: self, threadID: threadID) }
                }
                self.streamingText = ""
            case .streamChunk(let event):
                self.streamingText += event.chunk ?? ""
            case .thinking(let event):
                self.statusText = event.message ?? "思考中"
                self.inspectorEvents.insert(event.message ?? "思考中", at: 0)
            case .toolStarted(let event):
                self.inspectorEvents.insert("工具开始：\(event.toolName ?? "未知工具")", at: 0)
            case .toolCompleted(let event):
                self.inspectorEvents.insert("工具完成：\(event.toolName ?? "未知工具")", at: 0)
            case .toolResult(let event):
                self.inspectorEvents.insert("工具输出：\(event.preview ?? event.toolName ?? "结果")", at: 0)
            case .status(let event):
                self.statusText = event.message ?? "处理中"
            case .gateRequired:
                self.inspectorEvents.insert("需要人工确认", at: 0)
            case .gateResolved:
                self.inspectorEvents.insert("确认已处理", at: 0)
            case .authRequired(let event):
                self.pendingAuth = event
                self.inspectorEvents.insert("需要认证：\(event.extensionName)", at: 0)
            case .approvalNeeded(let event):
                self.pendingApproval = event
                self.inspectorEvents.insert("需要审批：\(event.toolName)", at: 0)
            case .jobStatus(let event):
                self.inspectorEvents.insert(event.message ?? "任务状态更新", at: 0)
            case .jobResult(let event):
                self.inspectorEvents.insert(event.message ?? "任务完成", at: 0)
            case .error(let event):
                self.statusText = event.message ?? "发生错误"
                self.inspectorEvents.insert(event.message ?? "发生错误", at: 0)
            case .heartbeat:
                break
            case .unknown(let type, _):
                self.inspectorEvents.insert("事件：\(type)", at: 0)
            }
        }

        logsSSE.onLogEntry = { [weak self] entry in
            guard let self else { return }
            self.logEntries.insert(entry, at: 0)
            if self.selectedLogEntryID == nil {
                self.selectedLogEntryID = entry.id
            }
            if self.logEntries.count > 200 {
                self.logEntries = Array(self.logEntries.prefix(200))
            }
            self.inspectorEvents.insert("[\(entry.level.uppercased())] \(entry.message)", at: 0)
            if self.inspectorEvents.count > 200 {
                self.inspectorEvents = Array(self.inspectorEvents.prefix(200))
            }
        }
    }
}
