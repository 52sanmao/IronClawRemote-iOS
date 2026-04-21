import Foundation

struct ThreadInfo: Codable, Identifiable, Hashable {
    let id: UUID
    let state: String
    let turnCount: Int
    let createdAt: String
    let updatedAt: String
    let title: String?
    let threadType: String?
    let channel: String?

    enum CodingKeys: String, CodingKey {
        case id, state, title, channel
        case turnCount = "turn_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case threadType = "thread_type"
    }
}

struct ThreadListResponse: Codable {
    let assistantThread: ThreadInfo?
    let threads: [ThreadInfo]
    let activeThread: UUID?

    enum CodingKeys: String, CodingKey {
        case threads
        case assistantThread = "assistant_thread"
        case activeThread = "active_thread"
    }
}

struct ImagePayload: Codable, Hashable {
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case data
        case mediaType = "media_type"
    }
}

struct SendMessageRequest: Codable {
    let content: String
    let threadId: String?
    let timezone: String?
    let images: [ImagePayload]

    enum CodingKeys: String, CodingKey {
        case content, timezone, images
        case threadId = "thread_id"
    }
}

struct SendMessageResponse: Codable {
    let messageId: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case status
        case messageId = "message_id"
    }
}

struct ToolCallInfo: Codable, Hashable {
    let name: String
    let hasResult: Bool
    let hasError: Bool
    let resultPreview: String?
    let error: String?
    let rationale: String?

    enum CodingKeys: String, CodingKey {
        case name, error, rationale
        case hasResult = "has_result"
        case hasError = "has_error"
        case resultPreview = "result_preview"
    }
}

struct GeneratedImageInfo: Codable, Hashable {
    let eventId: String
    let dataURL: String?
    let path: String?

    enum CodingKeys: String, CodingKey {
        case path
        case eventId = "event_id"
        case dataURL = "data_url"
    }
}

struct PendingGateInfo: Codable, Hashable {
    let requestId: String
    let threadId: String
    let gateName: String
    let toolName: String
    let description: String
    let parameters: String

    enum CodingKeys: String, CodingKey {
        case description, parameters
        case requestId = "request_id"
        case threadId = "thread_id"
        case gateName = "gate_name"
        case toolName = "tool_name"
    }
}

struct GateResolveRequest: Codable {
    let requestId: String
    let threadId: String?
    let resolution: GateResolutionPayload

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case threadId = "thread_id"
        case resolution
    }
}

enum GateResolutionPayload: Codable {
    case approved(always: Bool)
    case denied
    case cancelled

    private enum CodingKeys: String, CodingKey {
        case resolution
        case always
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolution = try container.decode(String.self, forKey: .resolution)
        switch resolution {
        case "approved":
            self = .approved(always: try container.decodeIfPresent(Bool.self, forKey: .always) ?? false)
        case "denied":
            self = .denied
        case "cancelled":
            self = .cancelled
        default:
            self = .denied
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .approved(let always):
            try container.encode("approved", forKey: .resolution)
            if always {
                try container.encode(always, forKey: .always)
            }
        case .denied:
            try container.encode("denied", forKey: .resolution)
        case .cancelled:
            try container.encode("cancelled", forKey: .resolution)
        }
    }
}

struct ActionResponse: Codable {
    let ok: Bool?
    let status: String?
    let message: String?
}

struct AuthTokenRequest: Codable {
    let extensionName: String
    let token: String
    let requestId: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case extensionName = "extension_name"
        case token
        case requestId = "request_id"
        case threadId = "thread_id"
    }
}

struct AuthCancelRequest: Codable {
    let extensionName: String
    let requestId: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case extensionName = "extension_name"
        case requestId = "request_id"
        case threadId = "thread_id"
    }
}

struct ApprovalResolveRequest: Codable {
    let requestId: String
    let threadId: String?
    let action: String

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case threadId = "thread_id"
        case action
    }
}

struct TurnInfo: Codable, Hashable {
    let turnNumber: Int
    let userInput: String
    let response: String?
    let state: String
    let startedAt: String
    let completedAt: String?
    let toolCalls: [ToolCallInfo]
    let generatedImages: [GeneratedImageInfo]
    let narrative: String?

    enum CodingKeys: String, CodingKey {
        case state, response, narrative
        case turnNumber = "turn_number"
        case userInput = "user_input"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case toolCalls = "tool_calls"
        case generatedImages = "generated_images"
    }
}

struct HistoryResponse: Codable {
    let threadId: UUID
    let turns: [TurnInfo]
    let hasMore: Bool
    let oldestTimestamp: String?
    let pendingGate: PendingGateInfo?

    enum CodingKeys: String, CodingKey {
        case turns
        case threadId = "thread_id"
        case hasMore = "has_more"
        case oldestTimestamp = "oldest_timestamp"
        case pendingGate = "pending_gate"
    }
}

struct ProfileResponse: Codable, Hashable {
    let createdAt: String
    let displayName: String
    let email: String?
    let id: String
    let lastLoginAt: String?
    let role: String
    let status: String
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case email, id, role, status
        case createdAt = "created_at"
        case displayName = "display_name"
        case lastLoginAt = "last_login_at"
        case avatarURL = "avatar_url"
    }
}

struct GatewayStatusResponse: Codable, Hashable {
    let sseConnections: Int
    let wsConnections: Int
    let totalConnections: Int
    let version: String?
    let uptimeSecs: Int?
    let llmBackend: String?
    let llmModel: String?
    let enabledChannels: [String]?

    enum CodingKeys: String, CodingKey {
        case version
        case sseConnections = "sse_connections"
        case wsConnections = "ws_connections"
        case totalConnections = "total_connections"
        case uptimeSecs = "uptime_secs"
        case llmBackend = "llm_backend"
        case llmModel = "llm_model"
        case enabledChannels = "enabled_channels"
    }
}
