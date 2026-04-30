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
