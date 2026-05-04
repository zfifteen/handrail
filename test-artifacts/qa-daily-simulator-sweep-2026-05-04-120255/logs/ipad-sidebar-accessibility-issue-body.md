## Reproduction steps

1. Build and launch Handrail on iPad Pro 13-inch (M5), iOS Simulator 26.4.1.
2. Start from the paired iPad Dashboard.
3. Inspect the accessibility hierarchy with XcodeBuildMCP `snapshot_ui`.
4. Try to activate sidebar navigation with XcodeBuildMCP `tap(label: "Chats")`.

## Expected behavior

Each iPad sidebar navigation item should be exposed as an individual accessible button, including `Dashboard`, `Chats`, `Attention`, `Activity`, `Alerts`, and `Settings`, and automation/VoiceOver users should be able to activate `Chats` directly by label.

## Observed behavior

The iPad sidebar is exposed as a single `Sidebar` group with no child elements in the accessibility hierarchy. `tap(label: "Chats")` fails with `No accessibility element matched --label 'Chats'`. Coordinate taps against the visible sidebar did not change selection during this run. The same sweep confirmed iPhone tab items are exposed as individual `Button` elements and can be activated by label.

## Affected surface

iPad sidebar navigation in the split-view workspace.

## Evidence

- Run artifacts: `test-artifacts/qa-daily-simulator-sweep-2026-05-04-120255/`
- iPad Dashboard screenshot with sidebar: `test-artifacts/qa-daily-simulator-sweep-2026-05-04-120255/mcp-screenshots/ipad-03-dashboard-relaunch.jpg`
- iPad chat-detail screenshot after entering Chats through a Dashboard row: `test-artifacts/qa-daily-simulator-sweep-2026-05-04-120255/mcp-screenshots/ipad-06-chat-detail-running.jpg`
- iPad project-grouping screenshot: `test-artifacts/qa-daily-simulator-sweep-2026-05-04-120255/mcp-screenshots/ipad-07-project-grouping.jpg`
- Notes with accessibility excerpt: `test-artifacts/qa-daily-simulator-sweep-2026-05-04-120255/notes.md`

## Verification needed

Rerun iPad simulator `snapshot_ui` and confirm the sidebar exposes individual navigation buttons. Then activate `Chats`, `Attention`, `Activity`, `Alerts`, and `Settings` by accessibility label and capture screenshots for the selected surfaces.
