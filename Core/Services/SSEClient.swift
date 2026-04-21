import Foundation

enum SSEEventPayload: Decodable {
    case response(ResponseEvent)
    case streamChunk(StreamChunkEvent)
    case thinking(StatusEvent)
    case toolStarted(ToolLifecycleEvent)
    case toolCompleted(ToolLifecycleEvent)
    case toolResult(ToolResultEvent)
    case status(StatusEvent)
    case gateRequired(GenericEvent)
    case gateResolved(GenericEvent)
    case authRequired(AuthRequiredEvent)
    case approvalNeeded(ApprovalNeededEvent)
    case jobStatus(GenericEvent)
    case jobResult(GenericEvent)
    case error(ErrorEvent)
    case heartbeat
    case unknown(String, [String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let type = try container.decode(String.self, forKey: DynamicCodingKey("type"))
        switch type {
        case "response": self = .response(try ResponseEvent(from: decoder))
        case "stream_chunk": self = .streamChunk(try StreamChunkEvent(from: decoder))
        case "thinking": self = .thinking(try StatusEvent(from: decoder))
        case "tool_started": self = .toolStarted(try ToolLifecycleEvent(from: decoder))
        case "tool_completed": self = .toolCompleted(try ToolLifecycleEvent(from: decoder))
        case "tool_result": self = .toolResult(try ToolResultEvent(from: decoder))
        case "status": self = .status(try StatusEvent(from: decoder))
        case "gate_required": self = .gateRequired(try GenericEvent(from: decoder))
        case "gate_resolved": self = .gateResolved(try GenericEvent(from: decoder))
        case "auth_required": self = .authRequired(try AuthRequiredEvent(from: decoder))
        case "approval_needed": self = .approvalNeeded(try ApprovalNeededEvent(from: decoder))
        case "job_status": self = .jobStatus(try GenericEvent(from: decoder))
        case "job_result": self = .jobResult(try GenericEvent(from: decoder))
        case "error": self = .error(try ErrorEvent(from: decoder))
        case "heartbeat": self = .heartbeat
        default:
            let raw = try Dictionary(from: decoder)
            self = .unknown(type, raw)
        }
    }
}

struct ResponseEvent: Decodable, Hashable {
    let content: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case content
        case threadId = "thread_id"
    }
}

struct StreamChunkEvent: Decodable, Hashable {
    let chunk: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case chunk
        case threadId = "thread_id"
    }
}

struct StatusEvent: Decodable, Hashable {
    let message: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case threadId = "thread_id"
    }
}

struct ToolLifecycleEvent: Decodable, Hashable {
    let toolName: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case threadId = "thread_id"
    }
}

struct ToolResultEvent: Decodable, Hashable {
    let toolName: String?
    let preview: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case preview
        case toolName = "tool_name"
        case threadId = "thread_id"
    }
}

struct AuthRequiredEvent: Decodable, Hashable {
    let extensionName: String
    let instructions: String?
    let authURL: String?
    let setupURL: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case extensionName = "extension_name"
        case instructions
        case authURL = "auth_url"
        case setupURL = "setup_url"
        case threadId = "thread_id"
    }
}

struct ApprovalNeededEvent: Decodable, Hashable {
    let requestId: String
    let toolName: String
    let description: String
    let parameters: String
    let allowAlways: Bool
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case toolName = "tool_name"
        case description
        case parameters
        case allowAlways = "allow_always"
        case threadId = "thread_id"
    }
}

struct GenericEvent: Decodable, Hashable {
    let message: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case threadId = "thread_id"
    }
}

struct ErrorEvent: Decodable, Hashable {
    let message: String?
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

struct AnyCodable: Codable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct Dictionary: Decodable {
    let value: [String: AnyCodable]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var result: [String: AnyCodable] = [:]
        for key in container.allKeys {
            result[key.stringValue] = try container.decode(AnyCodable.self, forKey: key)
        }
        value = result
    }
}

extension Dictionary {
    static func from(_ decoder: Decoder) throws -> [String: AnyCodable] {
        try Dictionary(from: decoder).value
    }
}

final class SSEClient: NSObject, URLSessionDataDelegate {
    var onEvent: ((SSEEventPayload) -> Void)?
    var onLogEntry: ((LogEntry) -> Void)?
    private var buffer = ""
    private var task: URLSessionDataTask?

    func connect(path: String, token: String, baseURL: URL) {
        disconnect()
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            return
        }
        let tokenQuery = URLQueryItem(name: "token", value: token)
        components.queryItems = (components.queryItems ?? []) + [tokenQuery]
        guard let url = components.url else { return }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        task = session.dataTask(with: request)
        task?.resume()
    }

    func disconnect() {
        task?.cancel()
        task = nil
        buffer = ""
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        let parts = buffer.components(separatedBy: "\n\n")
        buffer = parts.last ?? ""

        for chunk in parts.dropLast() {
            let lines = chunk.split(separator: "\n").map(String.init)
            let eventType = lines
                .first { $0.hasPrefix("event:") }
                .map { String($0.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            let dataLines = lines
                .filter { $0.hasPrefix("data:") }
                .map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
                .joined()
            guard !dataLines.isEmpty, let payload = dataLines.data(using: .utf8) else { continue }

            if eventType == "log", let decoded = try? JSONDecoder().decode(LogEntry.self, from: payload) {
                DispatchQueue.main.async { self.onLogEntry?(decoded) }
                continue
            }

            if let decoded = try? JSONDecoder().decode(SSEEventPayload.self, from: payload) {
                DispatchQueue.main.async { self.onEvent?(decoded) }
            }
        }
    }
}
