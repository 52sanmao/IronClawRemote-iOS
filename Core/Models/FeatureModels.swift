import Foundation

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var prettyString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self), let string = String(data: data, encoding: .utf8) else {
            return shortString
        }
        return string
    }

    var shortString: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.formatted()
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array:
            return prettyString
        case .null:
            return "null"
        }
    }
}

struct JobInfo: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let state: String
    let userId: String
    let createdAt: String
    let startedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, state
        case userId = "user_id"
        case createdAt = "created_at"
        case startedAt = "started_at"
    }
}

struct JobListResponse: Codable {
    let jobs: [JobInfo]
}

struct JobSummaryResponse: Codable, Hashable {
    let total: Int
    let pending: Int
    let inProgress: Int
    let completed: Int
    let failed: Int
    let stuck: Int

    enum CodingKeys: String, CodingKey {
        case total, pending, completed, failed, stuck
        case inProgress = "in_progress"
    }
}

struct TransitionInfo: Codable, Hashable, Identifiable {
    var id: String { "\(timestamp)-\(from)-\(to)" }
    let from: String
    let to: String
    let timestamp: String
    let reason: String?
}

struct JobDetailResponse: Codable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let state: String
    let userId: String
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let elapsedSecs: Int?
    let projectDir: String?
    let browseURL: String?
    let jobMode: String?
    let transitions: [TransitionInfo]
    let canRestart: Bool
    let canPrompt: Bool
    let jobKind: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, state, transitions
        case userId = "user_id"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case elapsedSecs = "elapsed_secs"
        case projectDir = "project_dir"
        case browseURL = "browse_url"
        case jobMode = "job_mode"
        case canRestart = "can_restart"
        case canPrompt = "can_prompt"
        case jobKind = "job_kind"
    }
}

struct JobActionResponse: Codable, Hashable {
    let status: String
    let jobID: String

    enum CodingKeys: String, CodingKey {
        case status
        case jobID = "job_id"
    }
}

struct JobPromptRequest: Codable {
    let content: String
    let done: Bool
}

struct JobEventInfo: Codable, Hashable, Identifiable {
    var id: String { "\(createdAt)-\(eventType)" }
    let eventType: String
    let data: JSONValue
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case data
        case eventType = "event_type"
        case createdAt = "created_at"
    }
}

struct JobEventsResponse: Codable {
    let jobID: String
    let events: [JobEventInfo]

    enum CodingKeys: String, CodingKey {
        case events
        case jobID = "job_id"
    }
}

struct ProjectFileEntry: Codable, Hashable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isDir: Bool

    enum CodingKeys: String, CodingKey {
        case name, path
        case isDir = "is_dir"
    }
}

struct ProjectFilesResponse: Codable {
    let entries: [ProjectFileEntry]
}

struct ProjectFileReadResponse: Codable, Hashable {
    let path: String
    let content: String
}

struct RoutineInfo: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let enabled: Bool
    let triggerSummary: String?
    let actionType: String?
    let lastRunAt: String?
    let nextFireAt: String?
    let runCount: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, enabled, status
        case triggerSummary = "trigger_summary"
        case actionType = "action_type"
        case lastRunAt = "last_run_at"
        case nextFireAt = "next_fire_at"
        case runCount = "run_count"
    }
}

struct RoutineListResponse: Codable {
    let routines: [RoutineInfo]
}

struct RoutineSummaryResponse: Codable, Hashable {
    let total: Int
    let enabled: Int
    let disabled: Int
    let unverified: Int
    let failing: Int
    let runsToday: Int

    enum CodingKeys: String, CodingKey {
        case total, enabled, disabled, unverified, failing
        case runsToday = "runs_today"
    }
}

struct RoutineRunInfo: Codable, Hashable, Identifiable {
    let id: UUID
    let triggerType: String
    let startedAt: String
    let completedAt: String?
    let status: String
    let resultSummary: String?
    let tokensUsed: Int?
    let jobId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, status
        case triggerType = "trigger_type"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case resultSummary = "result_summary"
        case tokensUsed = "tokens_used"
        case jobId = "job_id"
    }
}

struct RoutineDetailResponse: Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let enabled: Bool
    let triggerType: String
    let triggerRaw: String
    let triggerSummary: String
    let trigger: JSONValue
    let action: JSONValue
    let guardrails: JSONValue
    let notify: JSONValue
    let lastRunAt: String?
    let nextFireAt: String?
    let runCount: Int
    let consecutiveFailures: Int
    let status: String
    let verificationStatus: String
    let createdAt: String
    let conversationId: UUID?
    let recentRuns: [RoutineRunInfo]

    enum CodingKeys: String, CodingKey {
        case id, name, description, enabled, trigger, action, guardrails, notify, status
        case triggerType = "trigger_type"
        case triggerRaw = "trigger_raw"
        case triggerSummary = "trigger_summary"
        case lastRunAt = "last_run_at"
        case nextFireAt = "next_fire_at"
        case runCount = "run_count"
        case consecutiveFailures = "consecutive_failures"
        case verificationStatus = "verification_status"
        case createdAt = "created_at"
        case conversationId = "conversation_id"
        case recentRuns = "recent_runs"
    }
}

struct RoutineRunsResponse: Codable {
    let routineID: String
    let runs: [RoutineRunInfo]

    enum CodingKeys: String, CodingKey {
        case runs
        case routineID = "routine_id"
    }
}

struct RoutineActionResponse: Codable, Hashable {
    let status: String
    let routineID: String?
    let runID: String?

    enum CodingKeys: String, CodingKey {
        case status
        case routineID = "routine_id"
        case runID = "run_id"
    }
}

struct EngineMissionInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let goal: String
    let status: String
    let cadenceType: String
    let cadenceDescription: String
    let threadCount: Int
    let currentFocus: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, goal, status
        case cadenceType = "cadence_type"
        case cadenceDescription = "cadence_description"
        case threadCount = "thread_count"
        case currentFocus = "current_focus"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EngineMissionListResponse: Codable {
    let missions: [EngineMissionInfo]
}

struct EngineMissionSummaryResponse: Codable, Hashable {
    let total: UInt64
    let active: UInt64
    let paused: UInt64
    let completed: UInt64
    let failed: UInt64
}

struct EngineMissionDetailResponse: Codable, Hashable {
    let mission: JSONValue
}

struct EngineMissionFireResponse: Codable, Hashable {
    let threadID: String?
    let fired: Bool

    enum CodingKeys: String, CodingKey {
        case fired
        case threadID = "thread_id"
    }
}

struct EngineActionResponse: Codable, Hashable {
    let ok: Bool
}

struct EngineThreadInfo: Codable, Identifiable, Hashable {
    let id: String
    let goal: String
    let threadType: String
    let state: String
    let projectId: String
    let parentId: String?
    let stepCount: Int
    let totalTokens: UInt64
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, goal, state
        case threadType = "thread_type"
        case projectId = "project_id"
        case parentId = "parent_id"
        case stepCount = "step_count"
        case totalTokens = "total_tokens"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EngineThreadListResponse: Codable {
    let threads: [EngineThreadInfo]
}

struct EngineThreadDetailResponse: Codable {
    let thread: JSONValue
}

struct EngineStepInfo: Codable, Identifiable, Hashable {
    let id: String
    let sequence: Int
    let status: String
    let tier: String
    let actionResultsCount: Int
    let tokensInput: UInt64
    let tokensOutput: UInt64
    let startedAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, sequence, status, tier
        case actionResultsCount = "action_results_count"
        case tokensInput = "tokens_input"
        case tokensOutput = "tokens_output"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct EngineStepListResponse: Codable {
    let steps: [EngineStepInfo]
}

struct EngineEventListResponse: Codable {
    let events: [JSONValue]
}

struct EngineProjectInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdAt = "created_at"
    }
}

struct EngineProjectListResponse: Codable {
    let projects: [EngineProjectInfo]
}

struct TokenInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let tokenPrefix: String?
    let expiresAt: String?
    let lastUsedAt: String?
    let createdAt: String
    let revokedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case tokenPrefix = "token_prefix"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case revokedAt = "revoked_at"
    }
}

struct TokenListResponse: Codable {
    let tokens: [TokenInfo]
}

struct TokenCreateResponse: Codable {
    let token: String
    let id: String
    let name: String
    let tokenPrefix: String?
    let expiresAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case token, id, name
        case tokenPrefix = "token_prefix"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct TokenRevokeResponse: Codable {
    let status: String
    let id: String
}

struct AdminUserInfo: Codable, Identifiable, Hashable {
    let id: String
    let email: String?
    let displayName: String
    let status: String
    let role: String
    let createdAt: String
    let updatedAt: String
    let lastLoginAt: String?
    let createdBy: String?
    let jobCount: Int
    let totalCost: String
    let lastActiveAt: String?
    let metadata: JSONValue?

    enum CodingKeys: String, CodingKey {
        case id, email, status, role, metadata
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastLoginAt = "last_login_at"
        case createdBy = "created_by"
        case jobCount = "job_count"
        case totalCost = "total_cost"
        case lastActiveAt = "last_active_at"
    }
}

struct AdminUserListResponse: Codable {
    let users: [AdminUserInfo]
}

struct AdminUserCreateResponse: Codable {
    let id: String
    let email: String?
    let displayName: String
    let status: String
    let role: String
    let token: String
    let createdAt: String
    let createdBy: String?

    enum CodingKeys: String, CodingKey {
        case id, email, status, role, token
        case displayName = "display_name"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }
}

struct AdminUserStatusResponse: Codable {
    let id: String
    let status: String
}

struct AdminUserDeleteResponse: Codable {
    let id: String
    let deleted: Bool
}

struct MemoryListEntry: Codable, Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let isDir: Bool
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case name, path
        case isDir = "is_dir"
        case updatedAt = "updated_at"
    }
}

struct MemoryListResponse: Codable {
    let path: String
    let entries: [MemoryListEntry]
}

struct MemoryReadResponse: Codable, Hashable {
    let path: String
    let content: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case path, content
        case updatedAt = "updated_at"
    }
}

struct MemoryWriteRequest: Codable {
    let path: String
    let content: String
    let append: Bool?
    let force: Bool?
    let layer: String?
}

struct MemoryWriteResponse: Codable, Hashable {
    let path: String
    let status: String
    let redirected: Bool?
    let actualLayer: String?

    enum CodingKeys: String, CodingKey {
        case path, status, redirected
        case actualLayer = "actual_layer"
    }
}

struct MemorySearchRequest: Codable {
    let query: String
    let limit: Int?
}

struct MemorySearchHit: Codable, Hashable, Identifiable {
    var id: String { path }
    let path: String
    let content: String
    let score: Double
}

struct MemorySearchResponse: Codable {
    let results: [MemorySearchHit]
}

struct LogLevelResponse: Codable, Hashable {
    let level: String
}

struct LogEntry: Codable, Hashable, Identifiable {
    var id: String { "\(timestamp)-\(target)-\(message)" }
    let level: String
    let target: String
    let message: String
    let timestamp: String
}

struct LLMProviderInfo: Codable, Identifiable, Hashable {
    var id: String
    let name: String
    let adapter: String?
    let baseURL: String?
    let defaultModel: String?
    let apiKeyRequired: Bool?
    let hasAPIKey: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, adapter
        case baseURL = "base_url"
        case defaultModel = "default_model"
        case apiKeyRequired = "api_key_required"
        case hasAPIKey = "has_api_key"
    }
}

struct SettingsExportResponse: Codable {
    let settings: [String: JSONValue]
}

struct SettingResponse: Codable, Hashable, Identifiable {
    var id: String { key }
    let key: String
    let value: JSONValue
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case key, value
        case updatedAt = "updated_at"
    }
}

struct SettingsListResponse: Codable {
    let settings: [SettingResponse]
}

struct SettingWriteRequest: Codable {
    let value: JSONValue
}

struct SettingsImportRequest: Codable {
    let settings: [String: JSONValue]
}

struct ToolPermissionEntry: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let currentState: String
    let defaultState: String
    let locked: Bool
    let lockedReason: String?

    enum CodingKeys: String, CodingKey {
        case name, description, locked
        case currentState = "current_state"
        case defaultState = "default_state"
        case lockedReason = "locked_reason"
    }
}

struct ToolPermissionsResponse: Codable {
    let tools: [ToolPermissionEntry]
}

struct UpdateToolPermissionRequest: Codable {
    let state: String
}

enum ExtensionActivationStatus: String, Codable {
    case installed = "installed"
    case configured = "configured"
    case pairing = "pairing"
    case active = "active"
    case failed = "failed"
}

struct ExtensionInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let displayName: String?
    let kind: String
    let description: String?
    let url: String?
    let authenticated: Bool
    let active: Bool
    let tools: [String]
    let needsSetup: Bool
    let hasAuth: Bool
    let activationStatus: ExtensionActivationStatus?
    let activationError: String?
    let version: String?

    enum CodingKeys: String, CodingKey {
        case name, kind, description, url, authenticated, active, tools, version
        case displayName = "display_name"
        case needsSetup = "needs_setup"
        case hasAuth = "has_auth"
        case activationStatus = "activation_status"
        case activationError = "activation_error"
    }
}

struct ExtensionListResponse: Codable {
    let extensions: [ExtensionInfo]
}

struct RegistryEntryInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let displayName: String
    let kind: String
    let description: String
    let keywords: [String]
    let installed: Bool
    let version: String?

    enum CodingKeys: String, CodingKey {
        case name, kind, description, keywords, installed, version
        case displayName = "display_name"
    }
}

struct RegistrySearchResponse: Codable {
    let entries: [RegistryEntryInfo]
}

struct ToolInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let description: String
}

struct ToolListResponse: Codable {
    let tools: [ToolInfo]
}

struct InstallExtensionRequest: Codable {
    let name: String
    let url: String?
    let kind: String?
}

struct ExtensionSetupResponse: Codable {
    let name: String
    let kind: String
    let secrets: [SecretFieldInfo]
    let fields: [SetupFieldInfo]
}

struct SecretFieldInfo: Codable, Hashable {
    let name: String
    let prompt: String
    let optional: Bool
    let provided: Bool
    let autoGenerate: Bool

    enum CodingKeys: String, CodingKey {
        case name, prompt, optional, provided
        case autoGenerate = "auto_generate"
    }
}

struct SetupFieldInfo: Codable, Hashable {
    let name: String
    let prompt: String
    let optional: Bool
    let provided: Bool
    let inputType: String

    enum CodingKeys: String, CodingKey {
        case name, prompt, optional, provided
        case inputType = "input_type"
    }
}

struct ExtensionSetupRequest: Codable {
    let secrets: [String: String]?
    let fields: [String: String]?
}

struct SkillInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let version: String
    let trust: String
    let source: String
    let keywords: [String]
}

struct SkillListResponse: Codable {
    let skills: [SkillInfo]
    let count: Int
}

struct SkillSearchRequest: Codable {
    let query: String
}

struct SkillSearchResponse: Codable {
    let catalog: [JSONValue]
    let installed: [SkillInfo]
    let registryUrl: String
    let catalogError: String?

    enum CodingKeys: String, CodingKey {
        case catalog, installed
        case registryUrl = "registry_url"
        case catalogError = "catalog_error"
    }
}

struct SkillInstallRequest: Codable {
    let name: String
    let slug: String?
    let url: String?
    let content: String?
}
