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
| P0 | Continue archived Codex chats end-to-end | In progress | UI and protocol exist. Need a real consented run that proves `codex exec resume <session-id> <prompt>` creates a usable live session and streams output. |
| P0 | Pull-to-refresh feedback | Planned | Pull refresh currently requests a fresh session list. Add visible refresh state or timestamp so the user knows the list updated. |
| P1 | Start Session usability | In progress | Start now navigates to Session Detail. Add recent repo choices and clearer validation for invalid repo paths. |
| P1 | Session detail controls | Planned | Add a clear primary action for archived chats: continue, then navigate to the new live session when `session_started` arrives. |
| P1 | Connection state reliability | Planned | Show last successful sync time and a clear reconnect action when the WebSocket is offline. |
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
