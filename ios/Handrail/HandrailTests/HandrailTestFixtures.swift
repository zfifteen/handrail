import Foundation
@testable import Handrail

enum HandrailTestFixtures {
    static let baseDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

    static let pairedOnlineMachine = PairedMachine(
        protocolVersion: 1,
        host: "192.168.1.20",
        port: 8787,
        token: "fixture-token",
        machineName: "Fixture Mac",
        isOnline: true
    )

    static let pairedOfflineMachine = PairedMachine(
        protocolVersion: 1,
        host: "192.168.1.20",
        port: 8787,
        token: "fixture-token",
        machineName: "Fixture Mac",
        isOnline: false
    )

    static let runningChat = chat(id: "running-chat", title: "Running Chat", status: .running, offset: -600)
    static let waitingForApprovalChat = chat(id: "approval-chat", title: "Approval Chat", status: .waitingForApproval, offset: -500)
    static let failedChat = chat(id: "failed-chat", title: "Failed Chat", status: .failed, offset: -400)
    static let completedChat = chat(id: "completed-chat", title: "Completed Chat", status: .completed, offset: -300)
    static let stoppedChat = chat(id: "stopped-chat", title: "Stopped Chat", status: .stopped, offset: -200)
    static let idleChat = chat(id: "idle-chat", title: "Idle Chat", status: .idle, offset: -100)
    static let allStatusChats = [
        runningChat,
        waitingForApprovalChat,
        failedChat,
        completedChat,
        stoppedChat,
        idleChat
    ]

    static let pinnedChats = [
        chat(id: "pinned-one", title: "Pinned One", status: .completed, offset: -60, isPinned: true, pinnedOrder: 1),
        chat(id: "pinned-zero", title: "Pinned Zero", status: .running, offset: -50, isPinned: true, pinnedOrder: 0),
        chat(id: "unpinned", title: "Unpinned", status: .idle, offset: -40)
    ]
    static let dashboardMenuChats = [
        chat(id: "pinned-old", title: "Codex: Pinned Old", status: .completed, offset: -90_000, projectName: "Pinned Project", isPinned: true, pinnedOrder: 1),
        chat(id: "pinned-running", title: "Pinned Running", status: .running, offset: -120, projectName: "Pinned Project", isPinned: true, pinnedOrder: 0),
        chat(id: "all-running", title: "All Running", status: .running, offset: -3_600, projectName: "All Project", isAutomationTarget: true),
        chat(id: "all-completed", title: "All Completed", status: .completed, offset: -7_200, projectName: "All Project")
    ]
    static let dateSortedChats = [
        chat(id: "created-new", title: "Created New", status: .completed, offset: -10, updatedOffset: -90),
        chat(id: "updated-new", title: "Updated New", status: .completed, offset: -200, updatedOffset: -5),
        chat(id: "updated-old", title: "Updated Old", status: .completed, offset: -300, updatedOffset: -100)
    ]
    static let projectGroupedChats = [
        chat(id: "alpha-new", title: "Alpha New", status: .completed, offset: -10, projectName: "Alpha"),
        chat(id: "alpha-old", title: "Alpha Old", status: .completed, offset: -100, projectName: "Alpha"),
        chat(id: "beta-chat", title: "Beta Chat", status: .completed, offset: -50, projectName: "Beta")
    ]
    static let prefixedChat = chat(id: "prefixed-chat", title: "Codex: Readable task", status: .completed, offset: -30)
    static let rawIdentifierChat = chat(id: "raw-chat", title: "codex:550e8400-e29b-41d4-a716-446655440000", status: .completed, offset: -20)

    static let approval = ApprovalRequest(
        chatId: waitingForApprovalChat.id,
        approvalId: "approval-fixture",
        title: "Approval Required",
        summary: "Review deterministic fixture diff.",
        files: ["ios/Handrail/Handrail/Views/RootView.swift"],
        diff: "diff --git a/RootView.swift b/RootView.swift\n"
    )

    static let transcriptBlocks = [
        "User:\nImplement the iPad workspace.\n\n",
        "Thinking:\nInspect the root view, then preserve compact behavior.\n\n",
        "Codex:\nI added the scaffold and pending tests.\n\n",
        "Raw output:\n** BUILD SUCCEEDED **\n\n",
        "Failure:\nCommand failed with exit code 65.\n\n"
    ]

    static let emptyChats: [CodexChat] = []

    static func chat(
        id: String,
        title: String,
        status: ChatStatus,
        offset: TimeInterval,
        updatedOffset: TimeInterval? = nil,
        projectName: String = "Project",
        isPinned: Bool? = nil,
        pinnedOrder: Int? = nil,
        isAutomationTarget: Bool? = nil,
        hasUnreadTurn: Bool? = nil
    ) -> CodexChat {
        CodexChat(
            id: id,
            repo: "/Users/me/project",
            title: title,
            projectName: projectName,
            status: status,
            startedAt: baseDate.addingTimeInterval(offset),
            updatedAt: baseDate.addingTimeInterval(updatedOffset ?? offset + 30),
            endedAt: status == .running || status == .waitingForApproval ? nil : baseDate.addingTimeInterval(offset + 90),
            exitCode: status == .failed ? 1 : nil,
            files: ["README.md"],
            transcript: nil,
            thinking: nil,
            acceptsInput: status == .running,
            isPinned: isPinned,
            pinnedOrder: pinnedOrder,
            isAutomationTarget: isAutomationTarget,
            hasUnreadTurn: hasUnreadTurn
        )
    }
}
