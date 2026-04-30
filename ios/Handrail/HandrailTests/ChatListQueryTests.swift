import XCTest
@testable import Handrail

final class ChatListQueryTests: XCTestCase {
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
