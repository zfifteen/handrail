import XCTest
import SwiftUI
import UIKit
@testable import Handrail

final class RootLayoutSelectionTests: XCTestCase {
    func testCompactRootSelectionUsesPhoneRoot() {
        XCTAssertEqual(
            HandrailRootLayoutResolver.mode(userInterfaceIdiom: .pad, horizontalSizeClass: .compact),
            .phone
        )
        XCTAssertEqual(
            HandrailRootLayoutResolver.mode(userInterfaceIdiom: .phone, horizontalSizeClass: .regular),
            .phone
        )
    }

    func testRegularWidthIPadRootSelectionUsesIPadWorkspace() {
        XCTAssertEqual(
            HandrailRootLayoutResolver.mode(userInterfaceIdiom: .pad, horizontalSizeClass: .regular),
            .iPadRegular
        )
    }

    func testSectionSelectionPreservesSelectedChat() {
        var selection = IPadWorkspaceSelection(selectedSection: .chats, selectedChatId: "running-chat")

        selection.selectSection(.activity)

        XCTAssertEqual(selection.selectedSection, .activity)
        XCTAssertEqual(selection.selectedChatId, "running-chat")
        XCTAssertTrue(selection.hasDetailSelection)
    }

    func testSelectingChatRoutesToChatsAndClearsApproval() {
        var selection = IPadWorkspaceSelection(
            selectedSection: .attention,
            selectedChatId: "approval-chat",
            selectedApprovalId: "approval-chat\napproval-fixture"
        )

        selection.selectChat(id: "completed-chat")

        XCTAssertEqual(selection.selectedSection, .chats)
        XCTAssertEqual(selection.selectedChatId, "completed-chat")
        XCTAssertNil(selection.selectedApprovalId)
        XCTAssertTrue(selection.hasDetailSelection)
    }

    func testSelectingApprovalRoutesToAttentionAndKeepsChatContext() {
        var selection = IPadWorkspaceSelection(selectedSection: .dashboard)

        selection.selectApproval(id: "approval-chat\napproval-fixture", chatId: "approval-chat")

        XCTAssertEqual(selection.selectedSection, .attention)
        XCTAssertEqual(selection.selectedChatId, "approval-chat")
        XCTAssertEqual(selection.selectedApprovalId, "approval-chat\napproval-fixture")
        XCTAssertTrue(selection.hasDetailSelection)
    }

    func testIPadSidebarSectionsMatchVisibleNavigationItems() {
        XCTAssertEqual(
            HandrailSection.allCases.map(\.title),
            ["Dashboard", "Chats", "Attention", "Activity", "Alerts", "Settings"]
        )
    }
}

final class ChatDetailComposerStateTests: XCTestCase {
    func testFollowUpPendingStateDisablesSendControl() {
        XCTAssertTrue(ChatDetailComposerState.isSendDisabled(input: "Continue", isPending: true))
        XCTAssertFalse(ChatDetailComposerState.isSendDisabled(input: "Continue", isPending: false))
    }

    func testEmptyComposerInputDisablesSendControl() {
        XCTAssertTrue(ChatDetailComposerState.isSendDisabled(input: "  \n", isPending: false))
    }
}

final class ChatDetailApprovalResultTests: XCTestCase {
    func testApprovalResultAppearsOnlyForMatchingApprovalIdentity() {
        let approvalA = ApprovalRequest(chatId: "chat-a", approvalId: "shared", title: "Approval Required", summary: "A", files: [], diff: "")
        let approvalB = ApprovalRequest(chatId: "chat-b", approvalId: "shared", title: "Approval Required", summary: "B", files: [], diff: "")
        let result = ChatDetailApprovalResult(approvalId: approvalA.id, text: "Approved")

        XCTAssertEqual(result.text(for: approvalA), "Approved")
        XCTAssertNil(result.text(for: approvalB))
    }
}

final class NewChatBranchSelectionTests: XCTestCase {
    func testPathBackedNonDefaultProjectCanSelectBranch() {
        XCTAssertTrue(NewChatBranchSelection.canSelectBranch(projectPath: "/Users/me/OtherProject"))
    }

    func testProjectWithoutPathCannotSelectBranch() {
        XCTAssertFalse(NewChatBranchSelection.canSelectBranch(projectPath: nil))
        XCTAssertFalse(NewChatBranchSelection.canSelectBranch(projectPath: ""))
    }
}

final class PhoneRouteNavigationDecisionTests: XCTestCase {
    func testRepeatedNotificationForCurrentChatDoesNotRouteAgain() {
        XCTAssertFalse(PhoneRouteNavigationDecision.shouldRoute(currentChatId: "chat-a", routeChatId: "chat-a"))
    }

    func testDifferentNotificationChatRoutes() {
        XCTAssertTrue(PhoneRouteNavigationDecision.shouldRoute(currentChatId: "chat-a", routeChatId: "chat-b"))
        XCTAssertTrue(PhoneRouteNavigationDecision.shouldRoute(currentChatId: nil, routeChatId: "chat-a"))
    }
}
