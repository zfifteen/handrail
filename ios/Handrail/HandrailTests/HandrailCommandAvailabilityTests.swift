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
            selectedApprovalId: HandrailTestFixtures.approval.approvalId,
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
            selectedApprovalId: HandrailTestFixtures.approval.approvalId,
            latestApproval: HandrailTestFixtures.approval
        )

        XCTAssertFalse(commands.canStopSelectedChat)
        XCTAssertFalse(commands.canContinueSelectedChat)
        XCTAssertFalse(commands.canApproveSelectedRequest)
        XCTAssertFalse(commands.canDenySelectedRequest)
    }

    private func availability(
        pairedMachine: PairedMachine? = HandrailTestFixtures.pairedOnlineMachine,
        selectedChat: CodexChat? = nil,
        selectedApprovalId: String? = nil,
        latestApproval: ApprovalRequest? = nil
    ) -> HandrailCommandAvailability {
        HandrailCommandAvailability.resolve(
            pairedMachine: pairedMachine,
            selectedChat: selectedChat,
            selectedApprovalId: selectedApprovalId,
            latestApproval: latestApproval
        )
    }
}
