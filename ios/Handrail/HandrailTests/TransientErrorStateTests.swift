import XCTest
@testable import Handrail

@MainActor
final class TransientErrorStateTests: XCTestCase {
    func testOpeningNewChatClearsOnlyNewChatError() {
        let store = HandrailStore(enableNetworking: false)
        store.newChatError = "Codex Desktop did not become ready."
        store.notifications = [
            HandrailNotification(title: "Handrail error", detail: "Codex Desktop did not become ready.", date: HandrailTestFixtures.baseDate, chatId: nil)
        ]

        store.clearNewChatError()

        XCTAssertNil(store.newChatError)
        XCTAssertEqual(store.notifications.count, 1)
    }

    func testOpeningChatDetailClearsOnlyThatChatError() {
        let store = HandrailStore(enableNetworking: false)
        store.chatErrors = [
            "selected-chat": "Old selected chat error.",
            "other-chat": "Other chat error."
        ]

        store.clearChatError(chatId: "selected-chat")

        XCTAssertNil(store.chatErrors["selected-chat"])
        XCTAssertEqual(store.chatErrors["other-chat"], "Other chat error.")
    }
}
