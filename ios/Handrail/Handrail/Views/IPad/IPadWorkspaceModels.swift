import Foundation

enum HandrailSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case chats
    case attention
    case activity
    case alerts
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .chats: "Chats"
        case .attention: "Attention"
        case .activity: "Activity"
        case .alerts: "Alerts"
        case .settings: "Settings"
        }
    }
}

struct IPadWorkspaceSelection: Hashable {
    var selectedSection: HandrailSection = .dashboard
    var selectedChatId: String?
    var selectedApprovalId: String?
}

enum ChatListFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case running
    case waitingForApproval
    case failed
    case completed
    case stopped
    case idle

    var id: String { rawValue }
}

enum ChatListSort: String, CaseIterable, Identifiable, Hashable {
    case updated
    case created

    var id: String { rawValue }
}

struct HandrailCommandAvailability: Hashable {
    var canStartNewChat = false
    var canRefresh = false
    var canReconnect = false
    var canStopSelectedChat = false
    var canContinueSelectedChat = false
    var canApproveSelectedRequest = false
    var canDenySelectedRequest = false
}
