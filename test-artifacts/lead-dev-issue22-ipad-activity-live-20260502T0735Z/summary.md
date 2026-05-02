# Lead Dev Issue 22 iPad Live Validation

Run time: 2026-05-02T07:35Z

Target: GitHub issue #22, `iPad: Activity rows set a hidden chat selection`.

Simulator: iPad Pro 13-inch (M5), iOS Simulator 26.4.1.

Evidence:

- XcodeBuildMCP `test_sim` with `-only-testing:HandrailTests/RootLayoutSelectionTests`: 7/7 passed.
- XcodeBuildMCP `build_run_sim`: succeeded.
- Initial Activity state: only `Machine Online`, no chat-linked row.
- Live started chat id: `codex:019de79c-6c3f-7ae3-a4af-aef51c7597c1`.
- Live prompt: `Handrail issue 22 activity route check. Reply OK.`
- Server evidence: `chat_started`, chat-linked `chat_event`, and `chat_list` all referenced the same chat id.
- Acceptance result: tapping the chat-linked Activity row switched the iPad workspace to Chats and selected the same chat in detail.
- Screenshots:
  - `01-activity-chat-linked-row.jpg`
  - `02-activity-row-opened-chat-detail.jpg`

GitHub:

- #22 was closed.
- The first closure comment was mangled by shell command substitution around Markdown backticks.
- Corrected evidence comment: `https://github.com/zfifteen/handrail/issues/22#issuecomment-4363301058`.
