# Handrail Feature Roadmap

This file is updated by the recurring improvement task. Each run should choose one concrete improvement, implement it across CLI and iOS when applicable, test it, and update the status here.

## Priority Rules

1. Fix user-visible breakage before adding new capability.
2. Prefer improvements that make the iOS app and CLI agree on one observable contract.
3. Choose one improvement per run, but make it meaningfully user-visible or protocol-relevant.
4. Mark completion only after CLI tests, iOS build, and one runtime or protocol check pass.
5. Do not spend a run on polish, cleanup, refactors, or tiny conveniences unless they remove a real blocker observed in use.

## Backlog

| Priority | Feature | Status | Notes |
| --- | --- | --- | --- |
| P1 | Approval workflow hardening | Planned | Add deterministic fixtures for approval-like Codex output and diff display. |
| P2 | iOS pairing storage hardening | Planned | Move pairing token from UserDefaults to Keychain. |
| P2 | CLI state hygiene | Planned | Add a command to prune old Handrail-managed sessions without touching Codex history. |
| P2 | Test coverage expansion | Planned | Add WebSocket integration tests for start, continue, refresh, stop, and error events. |

## Completed

| Date | Feature | Verification |
| --- | --- | --- |
| 2026-04-25 | Sessions list uses Codex desktop chat names and `updated_at` ordering. | Server session list checked against Codex session index; iOS screenshot verified. |
| 2026-04-25 | Start Session navigates directly to Session Detail. | Simulator and physical iPhone build/install; WebSocket `session_started` path verified. |
| 2026-04-25 | Stopping a Handrail-managed session reports Stopped, not Failed. | CLI tests and runtime stop check. |
| 2026-04-25 | Archived Codex chats show a continue composer. | Simulator screenshot and invalid `continue_session` server error check. |
| 2026-04-25 | Transcript renders as role-separated rich text instead of raw monospace text. | Simulator screenshot. |
| 2026-04-26 | Transcript readability preserves line breaks from imported Codex chats. | CLI tests 4/4, iOS simulator build, WebSocket transcript-shape check, screenshot `test-artifacts/handrail-transcript-readable-2026-04-26.png`. |
| 2026-04-26 | Continue archived Codex chats creates a live chat-shaped session and routes to it. | CLI tests 5/5, deterministic fake-Codex protocol check, iOS simulator build, screenshot `test-artifacts/handrail-continue-routing-2026-04-26.png`. |
| 2026-04-26 | Pull-to-refresh feedback shows refresh progress and last sync time. | CLI tests 5/5, iOS simulator build, simulator launch screenshot `test-artifacts/handrail-refresh-feedback-2026-04-26.png`. |
| 2026-04-26 | Start Session offers recent Mac repositories and clearer disabled-state feedback. | CLI tests 5/5, iOS simulator build, simulator Start Session screenshot `test-artifacts/handrail-start-session-recent-repos-2026-04-26.png`. |
| 2026-04-26 | Archived Codex chat detail has a primary Continue Chat action. | CLI tests 5/5, iOS simulator build, simulator archived-chat screenshot `test-artifacts/handrail-archived-continue-control-2026-04-26.png`. |
| 2026-04-27 | Sync status has an explicit refresh/reconnect action. | CLI tests 5/5, iOS simulator build, simulator Dashboard screenshot `test-artifacts/handrail-sync-reconnect-action-2026-04-27.png`. |

## Run Log

### 2026-04-25

- Created this roadmap from the first MVP usability runs.
- Current highest priority remains proving archived-chat continuation end-to-end with an explicit user-approved test chat.

### 2026-04-26

- Completed the P0 transcript readability pass.
- CLI imported Codex transcript entries now use role-header blocks and Markdown hard line breaks outside code blocks.
- iOS transcript rendering now lays out each transcript body line separately while preserving inline Markdown and code lines.
- Verified with `npm test`, iOS simulator build, live WebSocket transcript-shape check, and simulator screenshot.
- Remaining highest-priority item: continue archived Codex chats end-to-end with an explicit user-approved test chat.

### 2026-04-26 Recurring Feature Run

- Completed the P0 archived-chat continuation path with deterministic verification.
- CLI live sessions now seed the transcript with the user's prompt and wrap Codex output as `Codex:` turns, so resumed chats enter the mobile UI as chat rounds instead of raw process output.
- iOS routing for newly started sessions now lives in `RootView`, so continuing an archived chat can navigate to the new live session from the app level.
- Verified with `cd cli && npm test`, an isolated fake-Codex continuation protocol check, iOS simulator build, and simulator screenshot.
- Remaining highest-priority item: pull-to-refresh feedback on the Dashboard/Sessions screens.

### 2026-04-26 Recurring Feature Run 2

- Completed the P0 pull-to-refresh feedback item.
- iOS now tracks session refresh progress and the timestamp of the last successful `session_list` response from the Mac.
- Dashboard and Sessions both show a visible sync row: `Refreshing from Mac...`, `Synced <time>`, or `Not synced yet`.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and screenshot.
- Remaining highest-priority item: Start Session usability, specifically recent repo choices and clearer invalid-path feedback.

### 2026-04-26 Recurring Feature Run 3

- Completed the P1 Start Session usability item.
- The Start Session sheet now preselects the most recently used repository reported by the Mac and offers the five most recent distinct repository paths as tappable choices.
- The Start button now has explicit disabled-state feedback for offline Mac, missing repo, missing title, and missing prompt states before any request is sent.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and screenshot.
- Remaining highest-priority item: Session detail controls for archived-chat continuation affordance.

### 2026-04-26 Recurring Feature Run 4

- Completed the P1 Session detail controls item.
- Archived Codex chat detail now shows a dedicated multiline continuation prompt and a full-width `Continue Chat` primary button instead of relying on a small paper-plane composer.
- If the Mac is offline, archived chats now explain that reconnecting is required before continuation is available.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and archived-chat screenshot.
- Remaining highest-priority item: Connection state reliability, specifically a clear reconnect action when the WebSocket is offline.

### 2026-04-27 Recurring Feature Run

- Completed the P1 Connection state reliability item.
- The store now exposes a manual reconnect path that reopens the paired Mac WebSocket and sends the pairing hello again.
- Dashboard and Sessions sync rows now show the last sync state plus a visible action: `Refresh` while online and `Reconnect` while offline.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and Dashboard screenshot.
- Remaining highest-priority item: Approval workflow hardening with deterministic approval-like output and diff fixtures.
