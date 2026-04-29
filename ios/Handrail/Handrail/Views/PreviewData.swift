import Foundation

@MainActor
enum PreviewData {
    static var store: HandrailStore {
        let store = HandrailStore(enableNetworking: false)
        store.pairedMachine = PairedMachine(protocolVersion: 1, host: "192.168.1.20", port: 8787, token: "preview", machineName: "MacBook Pro", isOnline: true)
        store.chats = [
            CodexChat(id: "preview-chat", repo: "/Users/me/project", title: "API Refactor", status: .waitingForApproval, startedAt: Date().addingTimeInterval(-340), endedAt: nil, exitCode: nil, files: ["cli/src/server.ts", "cli/src/chats.ts"])
        ]
        store.transcripts["preview-chat"] = ["Starting Codex...\n", "Do you want to proceed with these edits? y/n\n"]
        store.latestApproval = ApprovalRequest(chatId: "preview-chat", approvalId: "approval", title: "Approval Required", summary: "2 files changed", files: ["cli/src/server.ts", "cli/src/chats.ts"], diff: "diff --git a/cli/src/server.ts b/cli/src/server.ts\n")
        store.activity = [ActivityItem(title: "Approval requested", detail: "2 files changed", date: Date())]
        store.notifications = [HandrailNotification(title: "Approval required", detail: "API Refactor", date: Date(), chatId: "preview-chat")]
        store.connectionText = "Online"
        return store
    }
}
