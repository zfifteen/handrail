# Lead Dev Issue 21 iPad Live Validation

Run time: 2026-05-02T06:34:41Z

Target: GitHub issue #21, `iPad: New Chat sheet never closes on success`.

Simulator: iPad Pro 13-inch (M5), iOS Simulator 26.4.1.

Evidence:

- XcodeBuildMCP `test_sim` with `-only-testing:HandrailTests/RootLayoutSelectionTests`: 7/7 passed.
- XcodeBuildMCP `build_run_sim`: succeeded.
- Live iPad New Chat prompt: `Hi`.
- Started chat id: `codex:019de764-ba54-7d41-a819-3c75cad73b8f`.
- Acceptance result: the New Chat popover dismissed, the iPad UI switched to Chats, and the started chat was selected in detail.
- Screenshot: `issue21-ipad-selected-chat.jpg`.

Follow-up:

- `node cli/dist/src/index.js stop codex:019de764-ba54-7d41-a819-3c75cad73b8f` returned `Missing HANDRAIL_APNS_TEAM_ID.` noise and the chat still reported `running` after the settle check.
