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
| P2 | Test coverage expansion | Completed | Added WebSocket integration coverage for pairing, refresh, stop, and command error events. |

## Completed

| Date | Feature | Verification |
| --- | --- | --- |
| 2026-04-25 | Chat list uses Codex desktop chat names and `updated_at` ordering. | Server chat list checked against Codex chat index; iOS screenshot verified. |
| 2026-04-25 | New Chat navigates directly to Chat Detail. | Simulator and physical iPhone build/install; WebSocket `chat_started` path verified. |
| 2026-04-25 | Stopping a Codex chat reports Stopped, not Failed. | CLI tests and runtime stop check. |
| 2026-04-25 | Archived Codex chats show a continue composer. | Simulator screenshot and invalid `continue_chat` server error check. |
| 2026-04-25 | Transcript renders as role-separated rich text instead of raw monospace text. | Simulator screenshot. |
| 2026-04-26 | Transcript readability preserves line breaks from imported Codex chats. | CLI tests 4/4, iOS simulator build, WebSocket transcript-shape check, screenshot `test-artifacts/handrail-transcript-readable-2026-04-26.png`. |
| 2026-04-26 | Continue archived Codex chats creates a live Codex chat route. | Desktop protocol test, iOS simulator build, screenshot `test-artifacts/handrail-continue-routing-2026-04-26.png`. |
| 2026-04-26 | Pull-to-refresh feedback shows refresh progress and last sync time. | CLI tests 5/5, iOS simulator build, simulator launch screenshot `test-artifacts/handrail-refresh-feedback-2026-04-26.png`. |
| 2026-04-26 | New Chat offers recent Mac repositories and clearer disabled-state feedback. | CLI tests 5/5, iOS simulator build, simulator New Chat screenshot `test-artifacts/handrail-start-session-recent-repos-2026-04-26.png`. |
| 2026-04-26 | Archived Codex chat detail has a primary Continue Chat action. | CLI tests 5/5, iOS simulator build, simulator archived-chat screenshot `test-artifacts/handrail-archived-continue-control-2026-04-26.png`. |
| 2026-04-27 | Sync status has an explicit refresh/reconnect action. | CLI tests 5/5, iOS simulator build, simulator Dashboard screenshot `test-artifacts/handrail-sync-reconnect-action-2026-04-27.png`. |
| 2026-04-27 | Approval workflow hardening with deterministic approval fixture and inline approval controls. | CLI tests 15/15, iOS simulator build, WebSocket approval protocol check, simulator screenshot `test-artifacts/handrail-approval-hardening-2026-04-27.png`. |
| 2026-04-27 | iOS pairing token moved from UserDefaults to Keychain. | CLI tests 15/15, iOS simulator build, simulator launch, UserDefaults plist inspection, screenshot `test-artifacts/handrail-keychain-pairing-2026-04-27.png`. |
| 2026-04-28 | Removed legacy Handrail-owned chat records from the active product model. | CLI tests 16/16, direct isolated state check, iOS simulator build and launch, simulator screenshot `/var/folders/k_/spz3zlj566sc4qh29g0tk6jh0000gn/T/screenshot_optimized_5cebea27-b28c-42da-ba37-b203093ef80e.jpg`. |
| 2026-04-29 | WebSocket integration coverage for core chat protocol paths. | CLI tests 22/22, iOS simulator build, protocol-level WebSocket test for pair, refresh, stop, and error events. |
| 2026-04-29 | New Chat only shows Desktop-visible Codex chats. | CLI tests 20/20, simulator build and launch, simulator screenshot `/var/folders/k_/spz3zlj566sc4qh29g0tk6jh0000gn/T/screenshot_optimized_d1862fca-d63e-4b48-8cfc-fe5591036b99.jpg`. |
| 2026-04-29 | Notifications and chat records never expose raw Codex ids as titles. | CLI tests 26/26, iOS simulator build, raw `codex:<uuid>` title normalization test. |
| 2026-04-29 | Debug iPhone installs are not blocked by Push Notification provisioning. | CLI tests 26/26, iOS simulator build, iPhone Debug build, iPhone install. |
| 2026-04-29 | Debug builds do not attempt APNs registration without APNs entitlement. | CLI tests 26/26, simulator build, iPhone Debug build, iPhone install. |
| 2026-04-29 | Chat Detail empty states use live chat language, not transcript language. | CLI tests 26/26, simulator build and launch, simulator screenshot `test-artifacts/handrail-chat-language-2026-04-29.png`, iPhone Debug build and install. |
| 2026-04-30 | Task notifications never show raw Codex thread ids. | CLI tests 27/27, iOS simulator build and launch, simulator screenshot `/var/folders/k_/spz3zlj566sc4qh29g0tk6jh0000gn/T/screenshot_optimized_f4d9008a-11f2-4ebf-b1da-f3bc7ba535dd.jpg`, notification body fallback test. |

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
- Desktop chat routing now seeds the transcript with the user's prompt and wraps Codex output as `Codex:` turns, so resumed chats enter the mobile UI as chat rounds instead of raw process output.
- iOS routing for newly started chats now lives in `RootView`, so continuing an archived chat can navigate to the live chat from the app level.
- Verified with `cd cli && npm test`, a Desktop continuation protocol check, iOS simulator build, and simulator screenshot.
- Remaining highest-priority item: pull-to-refresh feedback on the Dashboard/Chats screens.

### 2026-04-26 Recurring Feature Run 2

- Completed the P0 pull-to-refresh feedback item.
- iOS now tracks chat refresh progress and the timestamp of the last successful `chat_list` response from the Mac.
- Dashboard and Chats both show a visible sync row: `Refreshing from Mac...`, `Synced <time>`, or `Not synced yet`.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and screenshot.
- Remaining highest-priority item: New Chat usability, specifically recent repo choices and clearer invalid-path feedback.

### 2026-04-26 Recurring Feature Run 3

- Completed the P1 New Chat usability item.
- The New Chat sheet now preselects the most recently used repository reported by the Mac and offers the five most recent distinct repository paths as tappable choices.
- The Start button now has explicit disabled-state feedback for offline Mac, missing repo, missing title, and missing prompt states before any request is sent.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and screenshot.
- Remaining highest-priority item: Chat detail controls for archived-chat continuation affordance.

### 2026-04-26 Recurring Feature Run 4

- Completed the P1 Chat detail controls item.
- Archived Codex chat detail now shows a dedicated multiline continuation prompt and a full-width `Continue Chat` primary button instead of relying on a small paper-plane composer.
- If the Mac is offline, archived chats now explain that reconnecting is required before continuation is available.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and archived-chat screenshot.
- Remaining highest-priority item: Connection state reliability, specifically a clear reconnect action when the WebSocket is offline.

### 2026-04-27 Recurring Feature Run

- Completed the P1 Connection state reliability item.
- The store now exposes a manual reconnect path that reopens the paired Mac WebSocket and sends the pairing hello again.
- Dashboard and Chats sync rows now show the last sync state plus a visible action: `Refresh` while online and `Reconnect` while offline.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, and Dashboard screenshot.
- Remaining highest-priority item: Approval workflow hardening with deterministic approval-like output and diff fixtures.

### 2026-04-27 Recurring Feature Run 2

- Completed the P1 approval workflow hardening item.
- CLI now has a deterministic fake approval agent fixture proving approval-like output emits `approval_required` with changed files and git diff.
- Chat detail now shows matched approval requests inline with changed files, optional diff, and Deny/Approve controls.
- `handrail serve` now keeps a real timer handle so detached local server commands stay alive.
- Verified with `cd cli && npm test`, iOS simulator build, WebSocket approval protocol check, simulator launch, and device build/install.
- Remaining highest-priority item: iOS pairing storage hardening.

### 2026-04-27 Recurring Feature Run 3

- Completed the P2 iOS pairing storage hardening item.
- Pairing tokens now save to Keychain under the Handrail service instead of inside the serialized UserDefaults machine record.
- Existing legacy UserDefaults pairings migrate on first launch: the token is copied to Keychain and the stored machine record is rewritten without the token.
- Verified with `cd cli && npm test`, iOS simulator build, simulator launch, UserDefaults plist inspection showing only host, port, protocol version, and machine name, and simulator screenshot.
- Remaining highest-priority item: CLI state hygiene.

### 2026-04-27 Recurring Feature Run 4

- Implemented the P2 CLI state hygiene item, but left it marked In progress until the iOS/device verification gate can run outside the current sandbox.
- Removed the active product path that stored Handrail-owned chat records in `~/.handrail/state.json`.
- Codex Desktop records remain the only visible chat source.
- Verified with `cd cli && npm test` and a direct CLI prune check against an isolated temporary `HOME`.
- Remaining blocker: current sandbox prevents Xcode's nested `sandbox-exec` macro build and prevents `devicectl` from initializing CoreDeviceService.

### 2026-04-28 Recurring Feature Run

- Completed the P2 CLI state hygiene item.
- The CLI now ignores legacy Handrail-owned records and serves Codex Desktop chats as the only visible chat source.
- Codex Desktop remains the source of truth for visible chat metadata.
- README now documents the prune command and the current pairing-token storage model: token in iOS Keychain, paired-machine metadata in UserDefaults.
- Verified with `cd cli && npm test`, a direct isolated CLI prune check, iOS simulator build, simulator launch, and simulator screenshot.
- Remaining highest-priority item: WebSocket integration test coverage for new chat, continue, refresh, stop, and error events.

### 2026-04-29 Recurring Feature Run

- Completed the P2 WebSocket integration test coverage item.
- The CLI server now exposes a narrow testable server factory so protocol behavior can be verified without launching the long-running daemon.
- Added an integration test proving a paired client receives machine status, New Chat options, chat list refreshes, stop acknowledgements, and scoped command errors.
- Verified with `cd cli && npm test` and an iOS simulator build.
- Built and installed the app on Dionisio's iPhone; launch was blocked by iOS because the device was locked.
- Remaining roadmap backlog is empty; the next run should add the highest-priority user-observed breakage before implementation begins.

### 2026-04-29 Recurring Feature Run 2

- Completed the P0 Desktop-visible New Chat item.
- New Chat creation now waits for Codex Desktop to expose the real `codex:` chat row before Handrail broadcasts `chat_started` or `chat_list`.
- If Codex Desktop does not expose the new chat, the CLI returns an explicit error and broadcasts no orphan mobile-only chat.
- Continued chats now overlay only an existing Desktop-visible row and still route through Codex Desktop.
- Verified with `cd cli && npm test`, iOS simulator build and launch, and simulator screenshot.
- Remaining highest-priority item: verify physical iPhone install when CoreDevice is available and the phone is connected.

### 2026-04-29 Recurring Feature Run 3

- Completed the P0 raw Codex id title cleanup item.
- The CLI now preserves Codex Desktop `first_user_message` metadata during visible chat import.
- Imported chat titles now reject raw UUID and `codex:<uuid>` values before they reach iOS lists, chat detail, or APNs notifications.
- If Desktop has not generated a human title yet, Handrail uses the rollout title or first user message; if neither exists, it uses the repository basename.
- Verified with `cd cli && npm test` and an iOS simulator build.
- Restarted the local Handrail server so the normalized title path is live.
- iPhone was connected, but device build/install is blocked by Apple provisioning: the personal development profile for `com.velocityworks.Handrail` does not include Push Notifications or `aps-environment`.

### 2026-04-29 Recurring Feature Run 4

- Completed the P0 local Debug installability item.
- The Debug target no longer requests the Push Notifications entitlement, so the personal Apple development team can sign the app for Dionisio's iPhone.
- Release still keeps `Handrail.entitlements`, preserving the push-capable build path for a team/profile that supports APNs.
- Verified with `cd cli && npm test`, iOS simulator build, exact iPhone Debug build, and `devicectl` install to Dionisio's iPhone.
- Launch was blocked because the phone was locked: `Unable to launch com.velocityworks.Handrail because the device was not, or could not be, unlocked.`

### 2026-04-29 Recurring Feature Run 5

- Completed the P0 Debug APNs registration cleanup item.
- Debug builds now configure local notifications without requesting remote push registration, matching the Debug signing profile that intentionally omits the APNs entitlement.
- Release builds still register for remote notifications, preserving the APNs path when a push-capable profile is used.
- Verified with `cd cli && npm test`, iOS simulator build, exact iPhone Debug build, and `devicectl` install to Dionisio's iPhone.
- Launch was blocked because the phone was locked: `Unable to launch com.velocityworks.Handrail because the device was not, or could not be, unlocked.`

### 2026-04-29 Recurring Feature Run 6

- Completed the P0 Chat Detail language item.
- Chat Detail empty states now describe missing chat messages instead of missing transcript output.
- Existing chats no longer surface transcript/archive wording when the chat has no visible messages.
- Verified with `cd cli && npm test`, iOS simulator build, simulator install and launch, simulator screenshot, exact iPhone Debug build, and `devicectl` install to Dionisio's iPhone.
- Launch was blocked because the phone was locked: `Unable to launch com.velocityworks.Handrail because the device was not, or could not be, unlocked.`

### 2026-04-30 Recurring Feature Run

- Completed the P0 task notification label item.
- CLI task notifications now reject raw UUID and `codex:<uuid>` chat labels before constructing completed, failed, approval-required, or input-required notification events.
- iOS local notification details now apply the same raw-id rejection and fall back to the human chat title, project name, repository basename, or `Codex chat`.
- Verified with `cd cli && npm test`, iOS simulator build and launch through XcodeBuildMCP, and simulator screenshot.
- Physical iPhone install could not run because `xcrun devicectl list devices` failed before listing devices: CoreDeviceService timed out while initializing.
