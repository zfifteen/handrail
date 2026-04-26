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

enum SessionStatus: String, Codable {
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

struct HandrailSession: Codable, Identifiable, Hashable {
    let id: String
    let repo: String
    let title: String
    var status: SessionStatus
    let startedAt: Date
    var updatedAt: Date? = nil
    var endedAt: Date?
    var exitCode: Int?
    var files: [String]?
    var source: String? = nil
    var transcript: [String]? = nil
    var acceptsInput: Bool? = nil
}

struct SessionEvent: Codable, Hashable {
    let kind: String
    let text: String?
    let status: SessionStatus?
    let at: Date?
}

struct ApprovalRequest: Codable, Identifiable, Hashable {
    var id: String { approvalId }
    let sessionId: String
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
    let sessionId: String?

    init(title: String, detail: String, date: Date, sessionId: String? = nil) {
        self.title = title
        self.detail = detail
        self.date = date
        self.sessionId = sessionId
    }
}

struct HandrailNotification: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let date: Date
    let sessionId: String?
}
