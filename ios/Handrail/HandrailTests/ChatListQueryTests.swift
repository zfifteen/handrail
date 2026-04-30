import XCTest
@testable import Handrail

final class ChatListQueryTests: XCTestCase {
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
        XCTAssertEqual(snapshot.allChatRows.map(\.leadingSystemImage), ["message.fill", "message.fill"])
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
}
