import XCTest
@testable import Handrail

final class TranscriptParsingTests: XCTestCase {
    func testChatBlockParserPreservesRoleRoundsAndBodies() {
        let transcript = """
        Codex: Existing summary
        User: First request
        Codex:
        First answer
        User:
        Second request
        Codex: Second answer
        """

        let blocks = ChatBlock.parse(transcript)

        XCTAssertEqual(blocks.map(\.role), [.codex, .user, .codex, .user, .codex])
        XCTAssertEqual(blocks.map(\.round), [1, 2, 2, 3, 3])
        XCTAssertEqual(blocks.map(\.startsRound), [true, true, false, true, false])
        XCTAssertEqual(blocks.map(\.body), [
            "Existing summary",
            "First request",
            "First answer",
            "Second request",
            "Second answer"
        ])
    }

    func testParserFallsBackToSingleCodexBlockForUnlabeledTranscript() {
        let blocks = ChatBlock.parse("raw output without a role")

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.role, .codex)
        XCTAssertEqual(blocks.first?.round, 1)
        XCTAssertEqual(blocks.first?.body, "raw output without a role")
        XCTAssertEqual(blocks.first?.startsRound, true)
    }

    func testRawMarkupDetectionAndFailureSummary() {
        let rawBlock = ChatBlock.parse("<!doctype html><html></html>").first

        XCTAssertEqual(rawBlock?.role, .codex)
        XCTAssertEqual(rawBlock?.isRawMarkupNoise, true)
        XCTAssertEqual(
            ChatBlock.failureSummary(from: "<!doctype html><html></html>"),
            "Codex produced raw markup output. The full raw response is contained below."
        )
        XCTAssertEqual(
            ChatBlock.failureSummary(from: "Enable JavaScript and cookies to continue"),
            "Codex received a browser challenge page instead of readable content."
        )
        XCTAssertEqual(ChatBlock.failureSummary(from: "first\r\nsecond\r\n"), "second")
    }

    func testThinkingEntriesUseVisibleTranscriptRound() {
        let blocks = ChatBlock.parse("""
        User:
        Run OODA
        Codex:
        Observe: The final answer remains visible.
        """)
        let entries = [
            ThinkingEntry(
                id: "thinking-1",
                round: 1,
                text: "Tool call: exec_command",
                at: nil
            )
        ]
        let view = ChatTranscriptView(
            blocks: blocks,
            thinkingEntries: entries,
            isWorking: false,
            error: nil,
            emptyText: "",
            expandedThinkingRounds: .constant([])
        )

        XCTAssertEqual(blocks.map(\.round), [1, 1])
        XCTAssertEqual(view.thinkingEntriesForDisplay(round: 1).map(\.text), ["Tool call: exec_command"])
    }

    func testThinkingDisclosureIsHiddenForRoundsWithoutEntries() {
        let blocks = ChatBlock.parse("""
        User:
        Earlier request
        Codex:
        Earlier answer
        User:
        Current request
        Codex:
        Current answer
        """)
        let view = ChatTranscriptView(
            blocks: blocks,
            thinkingEntries: [
                ThinkingEntry(id: "thinking-2", round: 2, text: "Tool call: exec_command", at: nil)
            ],
            isWorking: false,
            error: nil,
            emptyText: "",
            expandedThinkingRounds: .constant([])
        )

        XCTAssertFalse(view.shouldShowThinkingDisclosure(index: 1, round: 1))
        XCTAssertTrue(view.shouldShowThinkingDisclosure(index: 3, round: 2))
    }
}
