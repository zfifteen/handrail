# Handrail MVP Test Plan

## Scope

This plan covers the MVP path a user exercises on a Mac plus iPhone:

- Pair iPhone to the local Handrail server.
- Show Codex chat history from the same source used by Codex desktop.
- Start a new Handrail-managed Codex session from iOS.
- Stream transcript or failure output into Session Detail.
- Send input, stop a running session, and surface errors.
- Keep Sessions, Activity, Notifications, Approval, and Settings usable when empty, offline, or read-only.

## Desktop CLI Checks

1. `npm test` in `cli/`
   - TypeScript compiles.
   - Approval detection works.
   - Agent launch passes the initial prompt as a command argument.
   - Codex JSON events format into readable transcript lines.

2. WebSocket handshake
   - Connect to `ws://127.0.0.1:8788`.
   - Send `{ "type": "hello", "token": state.pairingToken }`.
   - Expect `machine_status` then `session_list`.

3. Session list source
   - Verify first sessions come from `~/.codex/session_index.jsonl` and `~/.codex/sessions`.
   - Verify list is ordered by `updated_at`.
   - Verify stale `~/.codex/archived_sessions` names are not used.

4. Start session smoke
   - Send `start_session` over WebSocket with repo, title, and prompt.
   - Expect `session_started`.
   - Expect either readable transcript output or `session_failed` with a visible error.
   - No start may leave the transcript stuck at a blank waiting state without an error.

5. Stop session smoke
   - Send `stop_session` for a running Handrail session.
   - Expect `session_stopped` and a refreshed `session_list`.

## iOS Checks

1. Build for physical device
   - `xcodebuild -project ios/Handrail/Handrail.xcodeproj -scheme Handrail -destination 'id=<device-udid>' -configuration Debug -allowProvisioningUpdates build`
   - Expect build success.

2. Install and launch on iPhone
   - Install the Debug iPhone build with `xcrun devicectl device install app`.
   - Launch `com.velocityworks.Handrail`.

3. Sessions tab
   - Paired machine shows Online when server is available.
   - Session names match Codex desktop names.
   - All Chats is ordered by last update.
   - Pinned is above All Chats.
   - Recent/Project filter is reachable.
   - Tab bar does not cover actionable rows.

4. Start Session sheet
   - Start is disabled when Mac is offline.
   - Start is disabled when title, repo, or prompt is empty.
   - Invalid/offline start shows an error instead of silently dismissing.
   - Valid start creates a session that navigates to useful status and transcript/failure output.

5. Session Detail
   - Running session says Codex is starting until output arrives.
   - Failed/stopped/completed sessions show status-specific empty text.
   - Failure text appears in transcript when no output was produced.
   - Imported Codex chats are marked read-only and do not show stop/input controls.

6. Pairing
   - A valid Handrail QR pairs and connects.
   - A malformed QR shows an error and scanner remains usable.

7. Alerts and Activity
   - Empty states are readable.
   - Error/completion notifications contain useful text.

## Current Environment Notes

- Local server port: `8788`.
- Physical iPhone bundle id: `com.velocityworks.Handrail`.
- Handrail should prefer the bundled Codex app CLI when available, then fall back to `HANDRAIL_AGENT_COMMAND`, then `codex`.

## 2026-04-25 Usability Pass

Executed against the local server on port `8788`, the booted iPhone 17 simulator, and Dionisio's connected iPhone.

- CLI unit tests: passed with 3/3 tests.
- iOS simulator build: passed.
- Physical iPhone build: passed.
- Physical iPhone install and launch: passed.
- Paired simulator state: online against `127.0.0.1:8788`.
- Sessions tab: verified Online state, Pinned, All chats, Recent filter, Project filter, and Codex chat title display.
- Start Session: verified title/repo/prompt entry, Start disabled while incomplete, valid Start sends WebSocket request, server returns `session_started`, app dismisses sheet, and app navigates directly to Session Detail.
- Session Detail: verified running state, completed state, transcript stream, and completed transcript text.
- Activity: verified session events appear and session-backed rows navigate to Session Detail.
- Notifications: verified completion notification appears and navigates to Session Detail.
- Approval: verified empty state.
- Settings: verified paired machine, `handrail pair` command, compatibility copy, and scanner fallback in simulator.
- Send input: verified an interactive session accepts text and streams the echoed output into the transcript.
- Stop: verified the stop button sends `stop_session`, terminates the subprocess, and displays Stopped rather than Failed.
- Pull-to-refresh: verified the Sessions tab refresh path sends a new authenticated `hello` and receives `machine_status` plus `session_list`.
- Continue archived chat: verified archived Codex chat details show a `Continue chat` composer when the Mac is online.
- Continue protocol: verified `continue_session` is accepted by the server and invalid archived ids return a visible error instead of silently doing nothing.
- Rich transcript: verified imported Codex transcript renders as role-separated rich text blocks rather than raw monospace/plain Markdown.

Screenshots:

- `test-artifacts/handrail-sessions-refreshable.png`
- `test-artifacts/handrail-rich-transcript-continue.png`

Observed fixed defects:

- Start Session used to dismiss back to Sessions without navigation. It now waits for `session_started` and opens the created session.
- Activity and Notifications used to be informational dead ends. Session-backed rows now open the related session.
- Stop previously raced the subprocess exit handler and could classify a user-stopped session as Failed. SIGTERM requested by Handrail is now classified as Stopped.
