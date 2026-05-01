import XCTest
@testable import Handrail

@MainActor
final class TransientErrorStateTests: XCTestCase {
    func testCommandResultDecodesAndRecordsActivity() throws {
        let json = """
        {
          "type": "command_result",
          "ok": true,
          "message": "Automation paused."
        }
        """

        let message = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        guard case .commandResult(let ok, let text) = message else {
            return XCTFail("Expected command result.")
        }
        XCTAssertTrue(ok)
        XCTAssertEqual(text, "Automation paused.")

        let store = HandrailStore(enableNetworking: false)
        store.handle(message)

        XCTAssertEqual(store.activity.first?.title, "Command result")
        XCTAssertEqual(store.activity.first?.detail, "Automation paused.")
        XCTAssertNil(store.lastError)
    }

    func testUnknownServerMessageTypeSurfacesProtocolError() throws {
        let json = """
        {
          "type": "desktop_repainted"
        }
        """

        let message = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        guard case .error(let text) = message else {
            return XCTFail("Expected protocol error.")
        }
        XCTAssertEqual(text, "Unsupported server message type: desktop_repainted.")

        let store = HandrailStore(enableNetworking: false)
        store.handle(message)

        XCTAssertEqual(store.lastError, "Unsupported server message type: desktop_repainted.")
        XCTAssertEqual(store.notifications.first?.title, "Handrail error")
        XCTAssertEqual(store.notifications.first?.detail, "Unsupported server message type: desktop_repainted.")
    }

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
