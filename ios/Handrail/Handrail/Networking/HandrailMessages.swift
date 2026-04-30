import Foundation

enum ClientMessage: Encodable {
    case hello(token: String)
    case registerPushToken(PushTokenRegistration)
    case startChat(StartChatPayload)
    case continueChat(chatId: String, prompt: String)
    case sendChatInput(chatId: String, text: String)
    case approve(chatId: String, approvalId: String)
    case deny(chatId: String, approvalId: String, reason: String)
    case stopChat(chatId: String)

    enum CodingKeys: String, CodingKey {
        case type
        case token
        case repo
        case title
        case prompt
        case chatId
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
        case deviceToken
        case environment
        case deviceName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let token):
            try container.encode("hello", forKey: .type)
            try container.encode(token, forKey: .token)
        case .registerPushToken(let registration):
            try container.encode("register_push_token", forKey: .type)
            try container.encode(registration.deviceToken, forKey: .deviceToken)
            try container.encode(registration.environment, forKey: .environment)
            try container.encodeIfPresent(registration.deviceName, forKey: .deviceName)
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
        case .continueChat(let chatId, let prompt):
            try container.encode("continue_chat", forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(prompt, forKey: .prompt)
        case .sendChatInput(let chatId, let text):
            try container.encode("send_chat_input", forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(text, forKey: .text)
        case .approve(let chatId, let approvalId):
            try container.encode("approve", forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(approvalId, forKey: .approvalId)
        case .deny(let chatId, let approvalId, let reason):
            try container.encode("deny", forKey: .type)
            try container.encode(chatId, forKey: .chatId)
            try container.encode(approvalId, forKey: .approvalId)
            try container.encode(reason, forKey: .reason)
        case .stopChat(let chatId):
            try container.encode("stop_chat", forKey: .type)
            try container.encode(chatId, forKey: .chatId)
        }
    }
}

enum ServerMessage: Decodable {
    case machineStatus(machineName: String, online: Bool, defaultRepo: String?)
    case newChatOptions(NewChatOptions)
    case automationList([AutomationRecord])
    case chatList([CodexChat])
    case chatStarted(CodexChat)
    case chatEvent(chatId: String, event: ChatEvent)
    case approvalRequired(ApprovalRequest)
    case error(String)
    case ignored

    enum CodingKeys: String, CodingKey {
        case type
        case machineName
        case online
        case chats
        case automations
        case chat
        case chatId
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
        case "automation_list":
            self = .automationList(try container.decode([AutomationRecord].self, forKey: .automations))
        case "chat_list":
            self = .chatList(try container.decode([CodexChat].self, forKey: .chats))
        case "chat_started":
            self = .chatStarted(try container.decode(CodexChat.self, forKey: .chat))
        case "chat_event":
            self = .chatEvent(
                chatId: try container.decode(String.self, forKey: .chatId),
                event: try container.decode(ChatEvent.self, forKey: .event)
            )
        case "approval_required":
            self = .approvalRequired(ApprovalRequest(
                chatId: try container.decode(String.self, forKey: .chatId),
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
