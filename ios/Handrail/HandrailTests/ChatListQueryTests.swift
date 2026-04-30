import XCTest
@testable import Handrail

final class ChatListQueryTests: XCTestCase {
    func testAutomationListDecodesPreviousServerPayload() throws {
        let json = """
        {
          "type": "automation_list",
          "automations": [
            {
              "id": "finish-handrail-ipad-app",
              "name": "Finish Handrail iPad App",
              "kind": "cron",
              "status": "ACTIVE",
              "scheduleText": "Hourly",
              "contextText": "handrail",
              "projectName": "handrail"
            }
          ]
        }
        """

        let message = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        guard case .automationList(let automations) = message else {
            return XCTFail("Expected automation list.")
        }

        XCTAssertEqual(automations.count, 1)
        XCTAssertEqual(automations[0].name, "Finish Handrail iPad App")
        XCTAssertEqual(automations[0].status, .active)
        XCTAssertEqual(automations[0].prompt, "")
        XCTAssertEqual(automations[0].cwds, [])
    }

    func testDashboardMenuSnapshotEntryPointIncludesDesktopShortcutOrder() {
        let snapshot = DashboardMenuQuery.snapshot(from: HandrailTestFixtures.pinnedChats, now: HandrailTestFixtures.baseDate)

        XCTAssertEqual(snapshot.shortcuts, [.newChat, .search, .plugins, .automations])
    }

    func testDashboardMenuShortcutsUseDesktopMenuLabelsAndIcons() {
        XCTAssertEqual(DashboardMenuShortcut.allCases.map(\.title), ["New chat", "Search", "Plugins", "Automations"])
        XCTAssertEqual(
            DashboardMenuShortcut.allCases.map(\.systemImage),
            ["square.and.pencil", "magnifyingglass", "puzzlepiece.extension", "clock"]
        )
    }

    func testDashboardMenuRowsUsePinnedAndAllChatsDisplayConventions() {
        let snapshot = DashboardMenuQuery.snapshot(
            from: HandrailTestFixtures.dashboardMenuChats,
            now: HandrailTestFixtures.baseDate
        )

        XCTAssertEqual(snapshot.pinnedRows.map(\.id), ["pinned-running", "pinned-old"])
        XCTAssertEqual(snapshot.allChatRows.map(\.id), ["all-running", "all-completed"])
        XCTAssertEqual(snapshot.pinnedRows.map(\.leadingSystemImage), ["pin.fill", "pin.fill"])
        XCTAssertEqual(snapshot.allChatRows.map(\.leadingSystemImage), [nil, nil])
        XCTAssertEqual(snapshot.pinnedRows.map(\.showsAutomationIndicator), [false, false])
        XCTAssertEqual(snapshot.allChatRows.map(\.showsAutomationIndicator), [true, false])
        XCTAssertEqual(snapshot.pinnedRows[0].timeText, "1m")
        XCTAssertEqual(snapshot.pinnedRows[1].timeText, "1d")
        XCTAssertEqual(snapshot.allChatRows[0].timeText, "59m")
        XCTAssertEqual(snapshot.allChatRows[1].timeText, "1h")
        XCTAssertEqual(snapshot.pinnedRows[0].displayTitle, "Pinned Running")
        XCTAssertEqual(snapshot.pinnedRows[1].displayTitle, "Pinned Old")
        XCTAssertTrue(snapshot.allChatRows[0].showsRunningIndicator)
        XCTAssertFalse(snapshot.allChatRows[1].showsRunningIndicator)
    }

    func testDashboardChatContextMenuUsesDesktopWording() {
        let snapshot = DashboardMenuQuery.snapshot(
            from: [
                HandrailTestFixtures.chat(
                    id: "pinned-read",
                    title: "Pinned Read",
                    status: .completed,
                    offset: -60,
                    isPinned: true,
                    hasUnreadTurn: false
                ),
                HandrailTestFixtures.chat(
                    id: "unpinned-unread",
                    title: "Unread",
                    status: .completed,
                    offset: -30,
                    hasUnreadTurn: true
                )
            ],
            now: HandrailTestFixtures.baseDate
        )

        XCTAssertEqual(snapshot.pinnedRows[0].pinActionTitle, "Unpin chat")
        XCTAssertEqual(snapshot.pinnedRows[0].readActionTitle, "Mark as unread")
        XCTAssertEqual(snapshot.allChatRows[0].pinActionTitle, "Pin chat")
        XCTAssertEqual(snapshot.allChatRows[0].readActionTitle, "Mark as read")
    }

    func testDashboardMenuDoesNotShowRunningIndicatorForApprovalWaitingChat() {
        let snapshot = DashboardMenuQuery.snapshot(
            from: [
                HandrailTestFixtures.runningChat,
                HandrailTestFixtures.waitingForApprovalChat
            ],
            now: HandrailTestFixtures.baseDate
        )

        XCTAssertEqual(snapshot.allChatRows.map(\.id), ["approval-chat", "running-chat"])
        XCTAssertFalse(snapshot.allChatRows[0].showsRunningIndicator)
        XCTAssertTrue(snapshot.allChatRows[1].showsRunningIndicator)
    }

    func testSearchByTitleProjectAndStatus() {
        let chats = HandrailTestFixtures.allStatusChats

        XCTAssertEqual(IPadChatListQuery.rows(from: chats, searchText: "running").map(\.id), ["running-chat"])
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, searchText: "project").count, chats.count)
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, searchText: "waiting for approval").map(\.id), ["approval-chat"])
    }

    func testFilterByStatus() {
        let chats = HandrailTestFixtures.allStatusChats

        XCTAssertEqual(IPadChatListQuery.rows(from: chats, filter: .running).map(\.id), ["running-chat"])
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, filter: .waitingForApproval).map(\.id), ["approval-chat"])
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, filter: .failed).map(\.id), ["failed-chat"])
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, filter: .completed).map(\.id), ["completed-chat"])
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, filter: .stopped).map(\.id), ["stopped-chat"])
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, filter: .idle).map(\.id), ["idle-chat"])
    }

    func testGroupByProject() {
        let groups = IPadChatListQuery.groupedRows(from: HandrailTestFixtures.projectGroupedChats)

        XCTAssertEqual(groups.map(\.project), ["Alpha", "Beta"])
        XCTAssertEqual(groups[0].rows.map(\.id), ["alpha-new", "alpha-old"])
        XCTAssertEqual(groups[1].rows.map(\.id), ["beta-chat"])
    }

    func testSortByUpdatedAndCreatedDates() {
        let chats = HandrailTestFixtures.dateSortedChats

        XCTAssertEqual(IPadChatListQuery.rows(from: chats, sort: .updated).map(\.id), ["updated-new", "created-new", "updated-old"])
        XCTAssertEqual(IPadChatListQuery.rows(from: chats, sort: .created).map(\.id), ["created-new", "updated-new", "updated-old"])
    }

    func testPinnedOrderingUsesDesktopMetadata() {
        let rows = IPadChatListQuery.rows(from: HandrailTestFixtures.pinnedChats)

        XCTAssertEqual(rows.map(\.id), ["pinned-zero", "pinned-one", "unpinned"])
    }

    func testDisplayTitleStripsCodexPrefixAndAvoidsRawIdentifiers() {
        XCTAssertEqual(IPadChatListQuery.displayTitle(for: HandrailTestFixtures.prefixedChat), "Readable task")
        XCTAssertEqual(IPadChatListQuery.displayTitle(for: HandrailTestFixtures.rawIdentifierChat), "Project")
    }

    func testChatListSummaryPreservesLoadedDetailFields() {
        var detailed = HandrailTestFixtures.runningChat
        detailed.files = ["Sources/App.swift"]
        detailed.transcript = ["User:\nInspect state.\n\n"]
        detailed.thinking = [
            ThinkingEntry(
                id: "thinking-1",
                round: 1,
                text: "The detail request already loaded thinking.",
                at: HandrailTestFixtures.baseDate
            )
        ]
        detailed.acceptsInput = true

        var summary = HandrailTestFixtures.chat(
            id: HandrailTestFixtures.runningChat.id,
            title: "Updated Running Chat",
            status: .running,
            offset: -600
        )
        summary.updatedAt = HandrailTestFixtures.baseDate.addingTimeInterval(10)
        summary.files = nil
        summary.transcript = nil
        summary.thinking = nil
        summary.acceptsInput = nil

        let merged = mergeChatListSummaries([summary], into: [detailed])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].title, "Updated Running Chat")
        XCTAssertEqual(merged[0].updatedAt, HandrailTestFixtures.baseDate.addingTimeInterval(10))
        XCTAssertEqual(merged[0].files, ["Sources/App.swift"])
        XCTAssertEqual(merged[0].transcript, ["User:\nInspect state.\n\n"])
        XCTAssertEqual(merged[0].thinking?.map(\.text), ["The detail request already loaded thinking."])
        XCTAssertEqual(merged[0].acceptsInput, true)
    }
}
