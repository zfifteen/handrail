# Handrail UI Path Issues

Simulator walk-through completed on 2026-04-28.

Guide document: `UI_PATHS.md`.

## Simulator Environment

- Device: iPhone 17 simulator, iOS 26.4.
- App bundle: `com.velocityworks.Handrail`.
- Paired machine shown by simulator: `MacBookPro.lan` at `192.168.40.18:8788`.
- Screenshot directory: `test-artifacts/ui-path-walkthrough-2026-04-28/`.

## Dashboard

- Issue: the dashboard can show stale sync state while still rendering current-looking chat rows.
  - Observed: `Synced 10:03` remained visible while the simulator clock was around 12:45 and chat rows showed relative ages such as `25m`.
  - Impact: the user cannot tell whether the dashboard data is fresh or stale.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/01-dashboard.png`.
- Issue: the dashboard top content is visually obscured by the collapsed navigation/header blur when returning from deeper routes.
  - Observed: the machine card and sync row are partially behind the top chrome while the dashboard body starts underneath it.
  - Impact: the default screen looks partially hidden instead of settled at a clean top position.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/01-dashboard.png`.

## Chats

- Issue: project-grouped chat display exposes raw directory slugs instead of desktop-style project names.
  - Observed examples: `novel-insight-engine-users-velocityworks-codex`, `files-mentioned-by-the-user-screenshot`, and other generated path-derived identifiers.
  - Impact: the grouped view does not match the desktop app vocabulary and is hard to scan.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/07-sessions-project-mode.png`.
- Issue: the `Chats` filter only exposes `Recent` and `Project`.
  - Observed: the menu has no visible sort choice beyond display mode.
  - Impact: it does not fully match the earlier desktop-like menu concept of display mode plus sort mode.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/06-sessions-filter-menu.png`.

## New Chat

- Issue: stale global errors leak into the `New chat` sheet.
  - Observed: opening a clean `New chat` sheet showed the prior `Codex Desktop did not become ready...` error at the bottom.
  - Impact: the user sees an unrelated failure before taking any action in the new flow.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/02-new-chat-empty.png`.
- Verified: the option menus are usable without the keyboard staying up.
  - Observed: opening `Work mode` after focusing the prompt collapsed the keyboard and showed the menu.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/04-new-chat-work-mode-menu.png`.
- Limitation: the simulator automation did not successfully insert prompt text into the `TextEditor`.
  - Observed: clicking the composer focused the field, but hardware-keyboard and paste attempts did not commit text.
  - Impact: the `Start` action was not executed during this pass to avoid guessing around simulator text input.

## Chat Detail

- Issue: stale global errors persist when reopening a chat detail.
  - Observed: reopening `PGS Lab` immediately displayed the previous `Codex Desktop did not become ready...` error.
  - Impact: the user cannot tell whether the currently viewed chat is failing now or whether the app is showing an old global error.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/08-session-detail-with-stale-error.png`.
- Issue: desktop chat content can render as raw process/log output rather than a readable Codex chat.
  - Observed: `PGS Lab` showed large raw Spring Boot log lines as the main chat content.
  - Impact: the detail view still behaves like a transcript dump for some desktop chats, not like a normal LLM chat thread.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/08-session-detail-with-stale-error.png`.
- Limitation: live send-input, stop, approval, and continue-success paths were not fully verified.
  - Observed state had no active controllable chat and no pending approval.
  - The continue-failure path was visible from prior state and was captured.

## Attention

- Verified: the empty attention state is clear.
  - Observed: `Nothing needs attention` plus explanatory text.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/09-attention-empty.png`.
- Limitation: dismiss item and dismiss-all paths were not exercised because no unresolved attention items were present.

## Approval

- Limitation: approval paths were not exercised.
  - Observed state had no pending approval.
  - The approval UI path exists in code and in `UI_PATHS.md`, but this simulator run did not have a live approval request to approve or deny.

## Activity

- Verified: activity list renders and can display machine-level events.
  - Observed: `Machine Online` event with machine name and time.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/10-activity.png`.
- Limitation: navigation from a chat-linked activity item was not exercised because the only visible activity item had no chat id.

## Alerts

- Issue: repeated global errors accumulate as alert rows with no visible dismiss or clear path.
  - Observed: two `Handrail error` entries with the same `Codex Desktop did not become ready...` message.
  - Impact: alerts become a stale error log instead of an actionable notification surface.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/12-alerts-errors.png`.

## Settings

- Verified: settings shows paired machine, pairing command, QR scanner entry point, app version, and compatibility copy.
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/13-settings.png`.

## Pairing Scanner

- Verified: scanner route opens and reports the simulator camera limitation.
  - Observed: `No camera is available.`
  - Evidence: `test-artifacts/ui-path-walkthrough-2026-04-28/14-pairing-scanner-no-camera.png`.
- Limitation: valid QR scan and invalid QR scan were not exercised because the iOS simulator has no camera.

## Coverage Summary

- Exercised in simulator:
  - Dashboard paired-machine state.
  - Dashboard chat-row navigation.
  - Chats tab.
  - Chats display filter.
  - Chats project grouping.
  - New Chat sheet.
  - New Chat project and work-mode menus.
  - Chat Detail archived-chat view.
  - Attention empty state.
  - Activity list.
  - More tab.
  - Alerts list.
  - Settings.
  - Pairing scanner no-camera state.
- Not exercised because required live data or device capability was absent:
  - Valid QR scan.
  - Invalid QR scan.
  - Start-chat success.
  - Continue-chat success.
  - Approval approve/deny.
  - Stop running chat.
  - Send live input.
  - Dismiss individual attention item.
  - Dismiss all attention items.
