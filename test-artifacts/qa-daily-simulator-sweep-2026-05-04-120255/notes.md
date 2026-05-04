# QA Daily Simulator Sweep 2026-05-04

## Targets

- iPhone: iPhone 17, iOS Simulator 26.4.1, UDID `0E58E7BB-44FA-4BEE-9C94-8FED4C334482`.
- iPad: iPad Pro 13-inch (M5), iOS Simulator 26.4.1, UDID `43913CAF-14DD-45B6-9633-0A9790474FC7`.
- App bundle: `com.velocityworks.Handrail`.
- Project: `ios/Handrail/Handrail.xcodeproj`.
- Scheme: `Handrail`.

## Context Reviewed

- `docs/team/qa-lead.md`.
- `docs/team/README.md`.
- `UI_PATHS.md`.
- `UI_PATH_ISSUES.md`.
- `docs/production_readiness_report.md`.
- `docs/product-invariants.md`.
- `TEST_PLAN.md`.
- Current GitHub bug issues via local `gh`.
- Closed bug issues updated since `2026-05-03T12:02:07Z` via local `gh`.
- Recent `#handrail-agents` Slack messages after the last run timestamp; no messages were present.

## Verification Results

- `cd cli && npm test`: passed 45/45.
- XcodeBuildMCP `test_sim` on iPhone 17: passed 49/49.
- XcodeBuildMCP `test_sim` on iPad Pro 13-inch (M5): timed out at the 120-second tool boundary before returning a full-suite result.
- XcodeBuildMCP focused iPad `test_sim -only-testing:HandrailTests/PairedMachineFormattingTests`: passed 1/1.
- Shell `tools/qa/simulator_sweep.sh` with explicit iPhone/iPad UDIDs failed because direct `simctl` access cannot connect to CoreSimulatorService in this automation context.

## Fixed-Issue Rechecks

- #31 remains fixed. The paired iPad Dashboard renders `127.0.0.1:8788` literally, with no thousands separator.
- iPad project grouping still renders readable names such as `Prime Gap Structure`; #12 remains fixed.
- The iPhone tab bar exposes `Dashboard`, `Chats`, `Attention`, `Activity`, and `More` as individual accessible buttons and label taps worked during this run.

## New Reproducible Finding

- Filed #32: `iPad sidebar navigation items are missing from accessibility tree`.
- Reproduction evidence:
  - iPad Dashboard screenshot: `mcp-screenshots/ipad-03-dashboard-relaunch.jpg`.
  - XcodeBuildMCP `snapshot_ui` on the iPad Dashboard exposed a single `Sidebar` group at `{{10, 32}, {260, 1334}}` with no children.
  - `tap(label: "Chats")` failed with `No accessibility element matched --label 'Chats'`.
  - Coordinate taps against the visible sidebar did not change the selected section during this run.
- Expected behavior: iPad sidebar entries should be individual accessible buttons for Dashboard, Chats, Attention, Activity, Alerts, and Settings.

## UI Paths Walked

- iPhone unpaired Dashboard.
- iPhone Chats unpaired state.
- iPhone Attention empty state.
- iPhone Activity empty state.
- iPhone More menu.
- iPhone Alerts with pairing-token repair notification.
- iPhone Settings pairing repair surface.
- iPhone Pairing Scanner no-camera state.
- iPad paired Dashboard.
- iPad Dashboard chat-row navigation into Chats split view.
- iPad running read-only Chat Detail.
- iPad project-grouped Chats list.

## Remaining Blockers

- #24 remains blocked because the live server still did not provide a real `waiting_for_approval` row during this sweep.
- Full iPad test-suite evidence is incomplete because the XcodeBuildMCP `test_sim` call timed out at 120 seconds.
- Direct shell `simctl` remains unavailable from this automation sandbox; XcodeBuildMCP remains the working simulator path.
- iPad sidebar accessibility/navigation bug #32 blocks full label-driven traversal of iPad sidebar routes.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: no product-invariant drift found. The sweep used local simulator targets, local repo state, local CLI tests, local Handrail server state, and local `gh` CLI only for GitHub.
