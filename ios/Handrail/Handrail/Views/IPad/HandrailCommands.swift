import SwiftUI

struct HandrailCommands: Commands {
    let store: HandrailStore
    @Binding var selection: IPadWorkspaceSelection
    @Binding var showsNewChat: Bool
    var supportsSelectedChatWindows = false

    var body: some Commands {
        SidebarCommands()

        CommandGroup(replacing: .newItem) {
            Button("New Chat") {
                showsNewChat = true
            }
            .disabled(!availability.canStartNewChat)
        }

        CommandMenu("View") {
            ForEach(HandrailSection.allCases) { section in
                Button(section.title) {
                    selection.selectSection(section)
                }
                .disabled(selection.selectedSection == section)
            }
        }

        CommandMenu("Chat") {
            Button("Refresh") {
                store.refreshChats()
            }
            .disabled(!availability.canRefresh)

            Button("Reconnect") {
                store.reconnect()
            }
            .disabled(!availability.canReconnect)

            Divider()

            Button("Stop Selected Chat") {
                stopSelectedChat()
            }
            .disabled(!availability.canStopSelectedChat)

            Button("Continue Selected Chat") {
                routeToSelectedChat()
            }
            .disabled(!availability.canContinueSelectedChat)
        }

        CommandMenu("Approval") {
            Button("Approve Selected Request") {
                approveSelectedRequest()
            }
            .disabled(!availability.canApproveSelectedRequest)

            Button("Deny Selected Request") {
                denySelectedRequest()
            }
            .disabled(!availability.canDenySelectedRequest)
        }

        CommandMenu("Window") {
            Button("New Window for Selected Chat") {}
                .disabled(!availability.canOpenSelectedChatWindow)
        }
    }

    private var target: HandrailCommandTarget {
        HandrailCommandTarget.resolve(
            pairedMachine: store.pairedMachine,
            chats: store.chats,
            latestApproval: store.latestApproval,
            selection: selection,
            supportsSelectedChatWindows: supportsSelectedChatWindows
        )
    }

    private var availability: HandrailCommandAvailability {
        target.availability
    }

    private func stopSelectedChat() {
        guard let chatId = target.selectedChat?.id else { return }
        store.stop(chatId: chatId)
    }

    private func routeToSelectedChat() {
        guard let chatId = target.selectedChat?.id else { return }
        selection.selectChat(id: chatId)
    }

    private func approveSelectedRequest() {
        guard let approval = selectedApproval else { return }
        store.approve(approval)
    }

    private func denySelectedRequest() {
        guard let approval = selectedApproval else { return }
        store.deny(approval, reason: "Denied from Handrail.")
    }

    private var selectedApproval: ApprovalRequest? {
        guard target.selectedApprovalId == store.latestApproval?.approvalId else { return nil }
        return store.latestApproval
    }
}
