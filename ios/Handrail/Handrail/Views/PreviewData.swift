import Foundation

@MainActor
enum PreviewData {
    static var store: HandrailStore {
        let store = HandrailStore(enableNetworking: false, loadStoredPairing: false)
        store.usesStaticPreviewData = true
        store.pairedMachine = PairedMachine(protocolVersion: 1, host: "192.168.1.20", port: 8787, token: "preview", machineName: "MacBook Pro", isOnline: true)
        store.chats = [
            CodexChat(
                id: "preview-chat",
                repo: "/Users/me/project",
                title: "API Refactor",
                status: .waitingForApproval,
                startedAt: Date().addingTimeInterval(-340),
                endedAt: nil,
                exitCode: nil,
                files: ["cli/src/server.ts", "cli/src/chats.ts"],
                transcript: nil,
                thinking: [
                    ThinkingEntry(
                        id: "thinking-preview",
                        round: 1,
                        text: "I need to inspect the API boundary, then check whether tests already cover the changed path.  ",
                        at: Date().addingTimeInterval(-120)
                    )
                ]
            ),
            CodexChat(
                id: "running-chat",
                repo: "/Users/me/IdeaProjects/handrail",
                title: "Codex: Running validation",
                projectName: "handrail",
                status: .running,
                startedAt: Date().addingTimeInterval(-180),
                updatedAt: Date().addingTimeInterval(-12),
                endedAt: nil,
                exitCode: nil,
                files: ["ios/Handrail/Handrail/Views/ChatDetailView.swift"],
                transcript: nil,
                thinking: [
                    ThinkingEntry(
                        id: "thinking-running",
                        round: 1,
                        text: "Inspecting the affected SwiftUI path and preparing the next simulator check.",
                        at: Date().addingTimeInterval(-30)
                    )
                ],
                acceptsInput: true
            ),
            CodexChat(
                id: "completed-chat",
                repo: "/Users/me/IdeaProjects/handrail",
                title: "Codex: Completed checkout",
                projectName: "handrail",
                status: .completed,
                startedAt: Date().addingTimeInterval(-720),
                updatedAt: Date().addingTimeInterval(-300),
                endedAt: Date().addingTimeInterval(-300),
                exitCode: 0,
                files: ["docs/design/phase-1-codex-clone-mockups/implementation-audit-20260508.md"],
                transcript: nil
            ),
            CodexChat(
                id: "failed-chat",
                repo: "/Users/me/IdeaProjects/handrail",
                title: "Codex: Failed build",
                projectName: "handrail",
                status: .failed,
                startedAt: Date().addingTimeInterval(-960),
                updatedAt: Date().addingTimeInterval(-900),
                endedAt: Date().addingTimeInterval(-900),
                exitCode: 65,
                files: nil,
                transcript: nil
            )
        ]
        store.transcripts["preview-chat"] = [
            "User:\nRefactor the API client and add regression tests.  \n\n",
            "Codex:\nI found the client boundary and prepared the smallest test-backed change.  \n\n"
        ]
        store.transcripts["running-chat"] = [
            "User:\nRun the simulator validation for the new chat shell.  \n\n",
            "Codex:\nI am building the app and checking the visible iPhone state now.  \n\n"
        ]
        store.transcripts["completed-chat"] = [
            "User:\nCapture the implementation audit and summarize the result.  \n\n",
            "Codex:\nThe audit file now records the verified simulator evidence and the unresolved desktop-reference gate.  \n\n"
        ]
        store.transcripts["failed-chat"] = [
            "User:\nRun the iOS build.  \n\n",
            "Codex:\nxcodebuild exited with code 65 after compiling the Handrail target.  \n\n"
        ]
        store.chatErrors["failed-chat"] = "xcodebuild exited with code 65."
        store.latestApproval = ApprovalRequest(chatId: "preview-chat", approvalId: "approval", title: "Approval Required", summary: "2 files changed", files: ["cli/src/server.ts", "cli/src/chats.ts"], diff: "diff --git a/cli/src/server.ts b/cli/src/server.ts\n")
        store.activity = [ActivityItem(title: "Approval requested", detail: "2 files changed", date: Date())]
        store.notifications = [HandrailNotification(title: "Approval required", detail: "API Refactor", date: Date(), chatId: "preview-chat")]
        store.newChatOptions = NewChatOptions(
            projects: [
                NewChatProject(id: "handrail", name: "handrail", path: "/Users/me/IdeaProjects/handrail"),
                NewChatProject(id: "prime-gap-structure", name: "prime-gap-structure", path: "/Users/me/IdeaProjects/prime-gap-structure")
            ],
            defaultProjectId: "handrail",
            branches: [
                NewChatBranch(name: "main", isCurrent: true),
                NewChatBranch(name: "phase-1-codex-clone", isCurrent: false)
            ],
            defaultBranch: "main",
            workModes: ["local", "worktree"],
            accessPresets: ["on_request", "read_only", "full_access"],
            defaultAccessPreset: "on_request",
            models: ["gpt-5.5"],
            defaultModel: "gpt-5.5",
            reasoningEfforts: ["medium", "high", "xhigh"],
            defaultReasoningEffort: "high"
        )
        store.automations = [
            AutomationRecord(
                id: "finish-handrail-ipad-app",
                name: "Finish Handrail iPad App",
                kind: "cron",
                status: .active,
                prompt: "Continue the GitHub issue #6 iPad Handrail implementation using the incremental-coder process.",
                rrule: "FREQ=HOURLY;INTERVAL=1",
                scheduleText: "Hourly",
                contextText: "handrail",
                projectName: "handrail",
                targetThreadId: nil,
                model: "gpt-5.2",
                reasoningEffort: "high",
                executionEnvironment: "local",
                cwds: ["/Users/me/IdeaProjects/handrail"]
            ),
            AutomationRecord(
                id: "handrail-bug-fix",
                name: "Handrail Bug Fix",
                kind: "heartbeat",
                status: .active,
                prompt: "Identify the highest severity unblocked bug, reproduce it, fix it, and verify it in the simulator.",
                rrule: "RRULE:FREQ=MINUTELY;INTERVAL=240",
                scheduleText: "Every 240m",
                contextText: "Heartbeat • Handrail Bug Fixes",
                projectName: nil,
                targetThreadId: "019dddba-dd9c-7140-b913-09bb7d645043",
                model: nil,
                reasoningEffort: nil,
                executionEnvironment: nil,
                cwds: []
            ),
            AutomationRecord(
                id: "gwr-dni",
                name: "GWR/DNI",
                kind: "cron",
                status: .paused,
                prompt: "Advance the prime gap structure experiment and summarize the next narrow result.",
                rrule: "FREQ=HOURLY;INTERVAL=8",
                scheduleText: "Paused",
                contextText: "prime-gap-structure",
                projectName: "prime-gap-structure",
                targetThreadId: nil,
                model: "gpt-5.2",
                reasoningEffort: "high",
                executionEnvironment: "local",
                cwds: ["/Users/me/IdeaProjects/prime-gap-structure"]
            )
        ]
        store.connectionText = "Online"
        return store
    }

    static var offlineStore: HandrailStore {
        let store = self.store
        store.pairedMachine = PairedMachine(protocolVersion: 1, host: "192.168.1.20", port: 8787, token: "preview", machineName: "MacBook Pro", isOnline: false)
        store.connectionText = "Offline"
        return store
    }

    static var emptyStore: HandrailStore {
        let store = HandrailStore(enableNetworking: false, loadStoredPairing: false)
        store.usesStaticPreviewData = true
        store.connectionText = "Offline"
        return store
    }

    static var emptyListStore: HandrailStore {
        let store = HandrailStore(enableNetworking: false, loadStoredPairing: false)
        store.usesStaticPreviewData = true
        store.pairedMachine = PairedMachine(protocolVersion: 1, host: "192.168.1.20", port: 8787, token: "preview", machineName: "MacBook Pro", isOnline: true)
        store.connectionText = "Online"
        store.chats = []
        return store
    }

    static var pairingSuccessStore: HandrailStore {
        let store = HandrailStore(enableNetworking: false, loadStoredPairing: false)
        store.usesStaticPreviewData = true
        store.pairedMachine = PairedMachine(protocolVersion: 1, host: "192.168.1.20", port: 8787, token: "preview", machineName: "MacBook Pro", isOnline: true)
        store.connectionText = "Online"
        return store
    }
}
