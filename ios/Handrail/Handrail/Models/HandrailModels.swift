import Foundation

struct PairingPayload: Codable {
    let protocolVersion: Int
    let host: String
    let port: Int
    let token: String
    let machineName: String
}

struct PairedMachine: Codable, Identifiable, Hashable {
    var id: String { "\(host):\(port)" }
    let protocolVersion: Int
    let host: String
    let port: Int
    let token: String
    let machineName: String
    var isOnline: Bool
}

enum ChatStatus: String, Codable {
    case running
    case waitingForApproval = "waiting_for_approval"
    case completed
    case failed
    case stopped
    case idle

    var title: String {
        switch self {
        case .running: "Running"
        case .waitingForApproval: "Waiting for approval"
        case .completed: "Completed"
        case .failed: "Failed"
        case .stopped: "Stopped"
        case .idle: "Idle"
        }
    }
}

struct CodexChat: Codable, Identifiable, Hashable {
    let id: String
    let repo: String
    let title: String
    var projectName: String? = nil
    var status: ChatStatus
    let startedAt: Date
    var updatedAt: Date? = nil
    var endedAt: Date?
    var exitCode: Int?
    var files: [String]?
    var transcript: [String]? = nil
    var thinking: [ThinkingEntry]? = nil
    var acceptsInput: Bool? = nil
    var isPinned: Bool? = nil
    var pinnedOrder: Int? = nil
    var isAutomationTarget: Bool? = nil
    var hasUnreadTurn: Bool? = nil
}

enum AutomationStatus: String, Codable {
    case active = "ACTIVE"
    case paused = "PAUSED"
}

struct AutomationRecord: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: String
    let status: AutomationStatus
    let prompt: String
    let rrule: String
    let scheduleText: String
    let contextText: String
    let projectName: String?
    let targetThreadId: String?
    let model: String?
    let reasoningEffort: String?
    let executionEnvironment: String?
    let cwds: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case status
        case prompt
        case rrule
        case scheduleText
        case contextText
        case projectName
        case targetThreadId
        case model
        case reasoningEffort
        case executionEnvironment
        case cwds
    }

    init(
        id: String,
        name: String,
        kind: String,
        status: AutomationStatus,
        prompt: String,
        rrule: String,
        scheduleText: String,
        contextText: String,
        projectName: String?,
        targetThreadId: String?,
        model: String?,
        reasoningEffort: String?,
        executionEnvironment: String?,
        cwds: [String]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.status = status
        self.prompt = prompt
        self.rrule = rrule
        self.scheduleText = scheduleText
        self.contextText = contextText
        self.projectName = projectName
        self.targetThreadId = targetThreadId
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.executionEnvironment = executionEnvironment
        self.cwds = cwds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(String.self, forKey: .kind)
        status = try container.decode(AutomationStatus.self, forKey: .status)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        rrule = try container.decodeIfPresent(String.self, forKey: .rrule) ?? ""
        scheduleText = try container.decode(String.self, forKey: .scheduleText)
        contextText = try container.decode(String.self, forKey: .contextText)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
        targetThreadId = try container.decodeIfPresent(String.self, forKey: .targetThreadId)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        reasoningEffort = try container.decodeIfPresent(String.self, forKey: .reasoningEffort)
        executionEnvironment = try container.decodeIfPresent(String.self, forKey: .executionEnvironment)
        cwds = try container.decodeIfPresent([String].self, forKey: .cwds) ?? []
    }
}

struct ThinkingEntry: Codable, Identifiable, Hashable {
    let id: String
    let round: Int
    let text: String
    let at: Date?
}

struct ChatEvent: Codable, Hashable {
    let kind: String
    let text: String?
    let status: ChatStatus?
    let at: Date?
}

struct ApprovalRequest: Codable, Identifiable, Hashable {
    var id: String { approvalId }
    let chatId: String
    let approvalId: String
    let title: String
    let summary: String
    let files: [String]
    let diff: String
}

struct ActivityItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date
    let chatId: String?

    init(title: String, detail: String, date: Date, chatId: String? = nil) {
        self.title = title
        self.detail = detail
        self.date = date
        self.chatId = chatId
    }
}

struct HandrailNotification: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date
    let chatId: String?
}

struct NewChatProject: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let path: String?
}

struct NewChatBranch: Codable, Hashable {
    let name: String
    let isCurrent: Bool
}

struct NewChatOptions: Codable, Hashable {
    let projects: [NewChatProject]
    let defaultProjectId: String
    let branches: [NewChatBranch]
    let defaultBranch: String
    let workModes: [String]
    let accessPresets: [String]
    let defaultAccessPreset: String
    let models: [String]
    let defaultModel: String
    let reasoningEfforts: [String]
    let defaultReasoningEffort: String
}

struct StartChatPayload: Hashable {
    let prompt: String
    let projectId: String
    let projectPath: String?
    let workMode: String
    let branch: String
    let newBranch: String?
    let accessPreset: String
    let model: String
    let reasoningEffort: String
}

struct PushTokenRegistration: Hashable {
    let deviceToken: String
    let environment: String
    let deviceName: String?
}
