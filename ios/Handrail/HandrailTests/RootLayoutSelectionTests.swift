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
            selectedApprovalId: "approval-fixture"
        )

        selection.selectChat(id: "completed-chat")

        XCTAssertEqual(selection.selectedSection, .chats)
        XCTAssertEqual(selection.selectedChatId, "completed-chat")
        XCTAssertNil(selection.selectedApprovalId)
        XCTAssertTrue(selection.hasDetailSelection)
    }

    func testSelectingApprovalRoutesToAttentionAndKeepsChatContext() {
        var selection = IPadWorkspaceSelection(selectedSection: .dashboard)

        selection.selectApproval(id: "approval-fixture", chatId: "approval-chat")

        XCTAssertEqual(selection.selectedSection, .attention)
        XCTAssertEqual(selection.selectedChatId, "approval-chat")
        XCTAssertEqual(selection.selectedApprovalId, "approval-fixture")
        XCTAssertTrue(selection.hasDetailSelection)
    }
}
