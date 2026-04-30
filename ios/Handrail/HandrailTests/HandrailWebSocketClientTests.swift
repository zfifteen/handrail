import Foundation
import XCTest
@testable import Handrail

final class HandrailWebSocketClientTests: XCTestCase {
    func testSendFailureMarksConnectionOfflineAndReportsError() {
        let task = TestWebSocketTask()
        let client = HandrailWebSocketClient { _ in task }
        var connectionChanges: [Bool] = []
        var errors: [String] = []

        client.onConnectionChange = { connectionChanges.append($0) }
        client.onMessage = { message in
            if case .error(let text) = message {
                errors.append(text)
            }
        }

        client.connect(to: HandrailTestFixtures.pairedOnlineMachine)
        client.send(.getChatDetail(chatId: HandrailTestFixtures.runningChat.id))
        task.completeSend(at: 1, with: NSError(domain: "HandrailWebSocketClientTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "send failed"
        ]))

        XCTAssertEqual(connectionChanges, [false])
        XCTAssertEqual(errors, ["send failed"])
        client.disconnect()
    }
}

private final class TestWebSocketTask: HandrailWebSocketTask {
    private var sendCompletions: [@Sendable (Error?) -> Void] = []

    func resume() {}

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}

    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping @Sendable (Error?) -> Void) {
        sendCompletions.append(completionHandler)
    }

    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {}

    func completeSend(at index: Int, with error: Error?) {
        sendCompletions[index](error)
    }
}
