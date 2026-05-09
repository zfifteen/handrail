import XCTest
@testable import Handrail

final class HandrailCommandAvailabilityTests: XCTestCase {
    func testSelectedChatCommandAvailability() {
        XCTAssertTrue(availability(selectedChat: HandrailTestFixtures.runningChat).canStopSelectedChat)
        XCTAssertTrue(availability(selectedChat: HandrailTestFixtures.waitingForApprovalChat).canStopSelectedChat)
        XCTAssertFalse(availability(selectedChat: HandrailTestFixtures.completedChat).canStopSelectedChat)

        XCTAssertTrue(availability(selectedChat: HandrailTestFixtures.completedChat).canContinueSelectedChat)
        XCTAssertTrue(availability(selectedChat: HandrailTestFixtures.failedChat).canContinueSelectedChat)
        XCTAssertTrue(availability(selectedChat: HandrailTestFixtures.stoppedChat).canContinueSelectedChat)
        XCTAssertTrue(availability(selectedChat: HandrailTestFixtures.idleChat).canContinueSelectedChat)
        XCTAssertFalse(availability(selectedChat: HandrailTestFixtures.runningChat).canContinueSelectedChat)
    }

    func testSelectedApprovalCommandAvailability() {
        let selected = availability(
            selectedApprovalId: HandrailTestFixtures.approval.id,
            latestApproval: HandrailTestFixtures.approval
        )
        XCTAssertTrue(selected.canApproveSelectedRequest)
        XCTAssertTrue(selected.canDenySelectedRequest)

        let mismatched = availability(
            selectedApprovalId: "different-approval",
            latestApproval: HandrailTestFixtures.approval
        )
        XCTAssertFalse(mismatched.canApproveSelectedRequest)
        XCTAssertFalse(mismatched.canDenySelectedRequest)
    }

    func testConnectionDerivedCommandAvailability() {
        let online = availability(pairedMachine: HandrailTestFixtures.pairedOnlineMachine)
        XCTAssertTrue(online.canStartNewChat)
        XCTAssertTrue(online.canRefresh)
        XCTAssertFalse(online.canReconnect)

        let offline = availability(pairedMachine: HandrailTestFixtures.pairedOfflineMachine)
        XCTAssertFalse(offline.canStartNewChat)
        XCTAssertFalse(offline.canRefresh)
        XCTAssertTrue(offline.canReconnect)

        let unpaired = availability(pairedMachine: nil)
        XCTAssertFalse(unpaired.canStartNewChat)
        XCTAssertFalse(unpaired.canRefresh)
        XCTAssertFalse(unpaired.canReconnect)
    }

    func testOfflineDisablesSelectedChatAndApprovalCommands() {
        let commands = HandrailCommandAvailability.resolve(
            pairedMachine: HandrailTestFixtures.pairedOfflineMachine,
            selectedChat: HandrailTestFixtures.runningChat,
            selectedApprovalId: HandrailTestFixtures.approval.id,
            latestApproval: HandrailTestFixtures.approval
        )

        XCTAssertFalse(commands.canStopSelectedChat)
        XCTAssertFalse(commands.canContinueSelectedChat)
        XCTAssertFalse(commands.canApproveSelectedRequest)
        XCTAssertFalse(commands.canDenySelectedRequest)
    }

    func testSelectedChatWindowCommandRequiresSceneSupportAndSelection() {
        XCTAssertTrue(
            availability(
                selectedChat: HandrailTestFixtures.runningChat,
                supportsSelectedChatWindows: true
            ).canOpenSelectedChatWindow
        )
        XCTAssertFalse(
            availability(
                selectedChat: HandrailTestFixtures.runningChat,
                supportsSelectedChatWindows: false
            ).canOpenSelectedChatWindow
        )
        XCTAssertFalse(
            availability(
                selectedChat: nil,
                supportsSelectedChatWindows: true
            ).canOpenSelectedChatWindow
        )
    }

    func testCommandTargetResolvesApprovalFromSelectedChat() {
        let target = HandrailCommandTarget.resolve(
            pairedMachine: HandrailTestFixtures.pairedOnlineMachine,
            chats: [HandrailTestFixtures.waitingForApprovalChat],
            latestApproval: HandrailTestFixtures.approval,
            selection: IPadWorkspaceSelection(
                selectedSection: .chats,
                selectedChatId: HandrailTestFixtures.waitingForApprovalChat.id
            )
        )

        XCTAssertEqual(target.selectedChat?.id, HandrailTestFixtures.waitingForApprovalChat.id)
        XCTAssertEqual(target.selectedApprovalId, HandrailTestFixtures.approval.id)
        XCTAssertTrue(target.availability.canApproveSelectedRequest)
        XCTAssertTrue(target.availability.canDenySelectedRequest)
    }

    func testCommandTargetPrefersExplicitApprovalSelection() {
        let target = HandrailCommandTarget.resolve(
            pairedMachine: HandrailTestFixtures.pairedOnlineMachine,
            chats: HandrailTestFixtures.allStatusChats,
            latestApproval: HandrailTestFixtures.approval,
            selection: IPadWorkspaceSelection(
                selectedSection: .attention,
                selectedChatId: HandrailTestFixtures.completedChat.id,
                selectedApprovalId: HandrailTestFixtures.approval.id
            )
        )

        XCTAssertEqual(target.selectedChat?.id, HandrailTestFixtures.completedChat.id)
        XCTAssertEqual(target.selectedApprovalId, HandrailTestFixtures.approval.id)
        XCTAssertTrue(target.availability.canApproveSelectedRequest)
        XCTAssertTrue(target.availability.canDenySelectedRequest)
    }

    private func availability(
        pairedMachine: PairedMachine? = HandrailTestFixtures.pairedOnlineMachine,
        selectedChat: CodexChat? = nil,
        selectedApprovalId: String? = nil,
        latestApproval: ApprovalRequest? = nil,
        supportsSelectedChatWindows: Bool = false
    ) -> HandrailCommandAvailability {
        HandrailCommandAvailability.resolve(
            pairedMachine: pairedMachine,
            selectedChat: selectedChat,
            selectedApprovalId: selectedApprovalId,
            latestApproval: latestApproval,
            supportsSelectedChatWindows: supportsSelectedChatWindows
        )
    }
}

final class NotificationIdentifierTests: XCTestCase {
    func testApprovalRequestIdentityIncludesChatIdAndApprovalId() {
        let left = ApprovalRequest(chatId: "chat-a", approvalId: "server-request-1", title: "Approval Required", summary: "A", files: [], diff: "")
        let right = ApprovalRequest(chatId: "chat-b", approvalId: "server-request-1", title: "Approval Required", summary: "B", files: [], diff: "")

        XCTAssertNotEqual(left.id, right.id)
        XCTAssertEqual(left.id, "chat-a\nserver-request-1")
    }

    func testApprovalNotificationIdentifierUsesChatIdAndApprovalId() {
        XCTAssertEqual(
            approvalNotificationIdentifier(
                chatId: "codex:019dc424-e857-76e0-8229-589ecf107eb4",
                approvalId: "server-request-1"
            ),
            "handrail.approval.codex:019dc424-e857-76e0-8229-589ecf107eb4.server-request-1"
        )
    }
}

final class HandrailLocalNotificationPolicyTests: XCTestCase {
    func testSchedulesLocalNotificationForUnseenChat() {
        XCTAssertTrue(HandrailLocalNotificationPolicy.shouldSchedule(isViewingChat: false))
    }

    func testSuppressesLocalNotificationForCurrentlyViewedChat() {
        XCTAssertFalse(HandrailLocalNotificationPolicy.shouldSchedule(isViewingChat: true))
    }
}
