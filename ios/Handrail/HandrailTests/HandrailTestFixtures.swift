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

    static let pinnedChats = [
        chat(id: "pinned-one", title: "Pinned One", status: .completed, offset: -60, isPinned: true, pinnedOrder: 1),
        chat(id: "pinned-zero", title: "Pinned Zero", status: .running, offset: -50, isPinned: true, pinnedOrder: 0),
        chat(id: "unpinned", title: "Unpinned", status: .idle, offset: -40)
    ]

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

    private static func chat(
        id: String,
        title: String,
        status: ChatStatus,
        offset: TimeInterval,
        isPinned: Bool? = nil,
        pinnedOrder: Int? = nil
    ) -> CodexChat {
        CodexChat(
            id: id,
            repo: "/Users/me/project",
            title: title,
            projectName: "Project",
            status: status,
            startedAt: baseDate.addingTimeInterval(offset),
            updatedAt: baseDate.addingTimeInterval(offset + 30),
            endedAt: status == .running || status == .waitingForApproval ? nil : baseDate.addingTimeInterval(offset + 90),
            exitCode: status == .failed ? 1 : nil,
            files: ["README.md"],
            transcript: nil,
            thinking: nil,
            acceptsInput: status == .running,
            isPinned: isPinned,
            pinnedOrder: pinnedOrder
        )
    }
}
