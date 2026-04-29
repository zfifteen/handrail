# Handrail MVP Test Plan

## Scope

This plan covers the MVP path a user exercises on a Mac plus iPhone:

- Pair iPhone to the local Handrail server.
- Show Codex chat history from the same source used by Codex desktop.
- Show and continue Codex chats from iOS.
- Stream transcript or failure output into Chat Detail.
- Request stop for a running Codex chat and surface errors.
- Keep Chats, Activity, Notifications, Approval, and Settings usable when empty, offline, or read-only.

## Desktop CLI Checks

1. `npm test` in `cli/`
   - TypeScript compiles.
   - Approval detection works.
   - Agent launch passes the initial prompt as a command argument.
   - Codex JSON events format into readable transcript lines.

2. WebSocket handshake
   - Connect to `ws://127.0.0.1:8788`.
   - Send `{ "type": "hello", "token": state.pairingToken }`.
   - Expect `machine_status` then `chat_list`.

3. Chat list source
   - Verify first chats come from Codex Desktop chat metadata and persisted Codex transcript files.
   - Verify list is ordered by `updated_at`.
   - Verify stale or unrelated files are not shown as chats.

4. New chat smoke
   - Send `start_chat` over WebSocket with prompt and options.
   - Expect either `chat_started` for a Codex Desktop chat or a visible deterministic error.
   - No start may create a Handrail-owned record.

5. Stop chat smoke
   - Send `stop_chat` for a running Codex chat.
   - Expect `chat_stopped` or a visible deterministic error and a refreshed `chat_list`.

## iOS Checks

1. Build for physical device
   - `xcodebuild -project ios/Handrail/Handrail.xcodeproj -scheme Handrail -destination 'id=<device-udid>' -configuration Debug -allowProvisioningUpdates build`
   - Expect build success.

2. Install and launch on iPhone
   - Install the Debug iPhone build with `xcrun devicectl device install app`.
   - Launch `com.velocityworks.Handrail`.

3. Chats tab
   - Paired machine shows Online when server is available.
   - Session names match Codex desktop names.
   - All Chats is ordered by last update.
   - Pinned is above All Chats.
   - Recent/Project filter is reachable.
   - Tab bar does not cover actionable rows.

4. New Chat sheet
   - Start is disabled when Mac is offline.
   - Start is disabled when title, repo, or prompt is empty.
   - Invalid/offline start shows an error instead of silently dismissing.
   - Valid start creates or opens a Codex chat that navigates to useful status and transcript/failure output.

5. Chat Detail
   - Running chat says Codex is starting until output arrives.
   - Failed/stopped/completed chats show status-specific empty text.
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
- Handrail should control Codex Desktop through the Desktop app's local IPC socket.

## 2026-04-25 Usability Pass

Executed against the local server on port `8788`, the booted iPhone 17 simulator, and Dionisio's connected iPhone.

- CLI unit tests: passed with 3/3 tests.
- iOS simulator build: passed.
- Physical iPhone build: passed.
- Physical iPhone install and launch: passed.
- Paired simulator state: online against `127.0.0.1:8788`.
- Chats tab: verified Online state, Pinned, All chats, Recent filter, Project filter, and Codex chat title display.
- New Chat: verified prompt/options entry, Start disabled while incomplete, valid Start sends WebSocket request, and successful starts navigate directly to Chat Detail.
- Chat Detail: verified running state, completed state, transcript stream, and completed transcript text.
- Activity: verified chat events appear and chat-backed rows navigate to Chat Detail.
- Notifications: verified completion notification appears and navigates to Chat Detail.
- Approval: verified empty state.
- Settings: verified paired machine, `handrail pair` command, compatibility copy, and scanner fallback in simulator.
- Send input: verified an interactive chat accepts text and streams output into the transcript when Codex Desktop exposes that route.
- Stop: verified the stop button sends `stop_chat` and displays scoped errors or Stopped.
- Pull-to-refresh: verified the Chats tab refresh path sends a new authenticated `hello` and receives `machine_status` plus `chat_list`.
- Continue archived chat: verified archived Codex chat details show a `Continue chat` composer when the Mac is online.
- Continue protocol: verified `continue_chat` is accepted by the server and invalid archived ids return a visible error instead of silently doing nothing.
- Rich transcript: verified imported Codex transcript renders as role-separated rich text blocks rather than raw monospace/plain Markdown.

Screenshots:

- `test-artifacts/handrail-sessions-refreshable.png`
- `test-artifacts/handrail-rich-transcript-continue.png`

Observed fixed defects:

- New Chat used to dismiss back to Chats without navigation. It now waits for `chat_started` and opens the created chat.
- Activity and Notifications used to be informational dead ends. Chat-backed rows now open the related chat.
- Stop now routes through the Codex chat protocol instead of a Handrail-owned process record.
