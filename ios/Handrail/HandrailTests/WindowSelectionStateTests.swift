import XCTest
@testable import Handrail

final class WindowSelectionStateTests: XCTestCase {
    func testSelectedChatWindowTitle() {
        XCTAssertEqual(IPadSelectedChatWindow.title(for: HandrailTestFixtures.prefixedChat), "Readable task")
        XCTAssertEqual(IPadSelectedChatWindow.title(for: HandrailTestFixtures.rawIdentifierChat), "Project")
        XCTAssertEqual(IPadSelectedChatWindow.title(for: nil), "Codex chat")
        XCTAssertFalse(IPadSelectedChatWindow.title(for: HandrailTestFixtures.rawIdentifierChat).lowercased().contains("codex:"))
    }

    func testSelectedChatWindowCreatesChatDetailSelection() {
        let window = IPadSelectedChatWindow(chatId: HandrailTestFixtures.completedChat.id)

        XCTAssertEqual(window.selection.selectedSection, .chats)
        XCTAssertEqual(window.selection.selectedChatId, HandrailTestFixtures.completedChat.id)
        XCTAssertNil(window.selection.selectedApprovalId)
    }

    @MainActor
    func testIndependentWindowSelection() {
        let store = HandrailStore(enableNetworking: false)
        store.chats = [
            HandrailTestFixtures.runningChat,
            HandrailTestFixtures.completedChat
        ]

        store.enterChat(chatId: HandrailTestFixtures.runningChat.id)
        store.enterChat(chatId: HandrailTestFixtures.completedChat.id)

        XCTAssertTrue(store.isViewingChat(chatId: HandrailTestFixtures.runningChat.id))
        XCTAssertTrue(store.isViewingChat(chatId: HandrailTestFixtures.completedChat.id))

        store.leaveChat(chatId: HandrailTestFixtures.runningChat.id)

        XCTAssertFalse(store.isViewingChat(chatId: HandrailTestFixtures.runningChat.id))
        XCTAssertTrue(store.isViewingChat(chatId: HandrailTestFixtures.completedChat.id))
        XCTAssertEqual(store.chat(id: HandrailTestFixtures.runningChat.id)?.status, .running)
        XCTAssertEqual(store.chat(id: HandrailTestFixtures.completedChat.id)?.status, .completed)
    }

    @MainActor
    func testMultipleWindowsViewingSameChatKeepViewingUntilLastWindowCloses() {
        let store = HandrailStore(enableNetworking: false)

        store.enterChat(chatId: HandrailTestFixtures.runningChat.id)
        store.enterChat(chatId: HandrailTestFixtures.runningChat.id)
        store.leaveChat(chatId: HandrailTestFixtures.runningChat.id)

        XCTAssertTrue(store.isViewingChat(chatId: HandrailTestFixtures.runningChat.id))

        store.leaveChat(chatId: HandrailTestFixtures.runningChat.id)

        XCTAssertFalse(store.isViewingChat(chatId: HandrailTestFixtures.runningChat.id))
    }
}
