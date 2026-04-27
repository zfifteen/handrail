import Foundation

enum ClientMessage: Encodable {
    case hello(token: String)
    case startSession(repo: String, title: String, prompt: String)
    case startChat(StartChatPayload)
    case continueSession(sessionId: String, prompt: String)
    case sendInput(sessionId: String, text: String)
    case approve(sessionId: String, approvalId: String)
    case deny(sessionId: String, approvalId: String, reason: String)
    case stopSession(sessionId: String)

    enum CodingKeys: String, CodingKey {
        case type
        case token
        case repo
        case title
        case prompt
        case sessionId
        case text
        case approvalId
        case reason
        case projectId
        case projectPath
        case workMode
        case branch
        case newBranch
        case accessPreset
        case model
        case reasoningEffort
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let token):
            try container.encode("hello", forKey: .type)
            try container.encode(token, forKey: .token)
        case .startSession(let repo, let title, let prompt):
            try container.encode("start_session", forKey: .type)
            try container.encode(repo, forKey: .repo)
            try container.encode(title, forKey: .title)
            try container.encode(prompt, forKey: .prompt)
        case .startChat(let payload):
            try container.encode("start_chat", forKey: .type)
            try container.encode(payload.prompt, forKey: .prompt)
            try container.encode(payload.projectId, forKey: .projectId)
            try container.encodeIfPresent(payload.projectPath, forKey: .projectPath)
            try container.encode(payload.workMode, forKey: .workMode)
            try container.encode(payload.branch, forKey: .branch)
            try container.encodeIfPresent(payload.newBranch, forKey: .newBranch)
            try container.encode(payload.accessPreset, forKey: .accessPreset)
            try container.encode(payload.model, forKey: .model)
            try container.encode(payload.reasoningEffort, forKey: .reasoningEffort)
        case .continueSession(let sessionId, let prompt):
            try container.encode("continue_session", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(prompt, forKey: .prompt)
        case .sendInput(let sessionId, let text):
            try container.encode("send_input", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(text, forKey: .text)
        case .approve(let sessionId, let approvalId):
            try container.encode("approve", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(approvalId, forKey: .approvalId)
        case .deny(let sessionId, let approvalId, let reason):
            try container.encode("deny", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(approvalId, forKey: .approvalId)
            try container.encode(reason, forKey: .reason)
        case .stopSession(let sessionId):
            try container.encode("stop_session", forKey: .type)
            try container.encode(sessionId, forKey: .sessionId)
        }
    }
}

enum ServerMessage: Decodable {
    case machineStatus(machineName: String, online: Bool, defaultRepo: String?)
    case newChatOptions(NewChatOptions)
    case sessionList([HandrailSession])
    case sessionStarted(HandrailSession)
    case sessionEvent(sessionId: String, event: SessionEvent)
    case approvalRequired(ApprovalRequest)
    case error(String)
    case ignored

    enum CodingKeys: String, CodingKey {
        case type
        case machineName
        case online
        case sessions
        case session
        case sessionId
        case event
        case approvalId
        case title
        case summary
        case files
        case diff
        case message
        case defaultRepo
        case options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "machine_status":
            self = .machineStatus(
                machineName: try container.decode(String.self, forKey: .machineName),
                online: try container.decode(Bool.self, forKey: .online),
                defaultRepo: try container.decodeIfPresent(String.self, forKey: .defaultRepo)
            )
        case "new_chat_options":
            self = .newChatOptions(try container.decode(NewChatOptions.self, forKey: .options))
        case "session_list":
            self = .sessionList(try container.decode([HandrailSession].self, forKey: .sessions))
        case "session_started":
            self = .sessionStarted(try container.decode(HandrailSession.self, forKey: .session))
        case "session_event":
            self = .sessionEvent(
                sessionId: try container.decode(String.self, forKey: .sessionId),
                event: try container.decode(SessionEvent.self, forKey: .event)
            )
        case "approval_required":
            self = .approvalRequired(ApprovalRequest(
                sessionId: try container.decode(String.self, forKey: .sessionId),
                approvalId: try container.decode(String.self, forKey: .approvalId),
                title: try container.decode(String.self, forKey: .title),
                summary: try container.decode(String.self, forKey: .summary),
                files: try container.decode([String].self, forKey: .files),
                diff: try container.decode(String.self, forKey: .diff)
            ))
        case "error":
            self = .error(try container.decode(String.self, forKey: .message))
        default:
            self = .ignored
        }
    }
}
