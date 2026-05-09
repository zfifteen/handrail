# Phase 1 Reference Comparison Map

Use this map after the required Codex Desktop reference screenshots exist in `references/`.

The comparison gate is not passable until every `Desktop Reference` file exists and each mapped simulator screenshot has been reviewed against it.

Current blocker as of the 2026-05-08 21:53 EDT inspection: `references/` contains only `BLOCKED.md`; all eleven required `desktop-*.png` files are absent, `reference-comparison-review.md` is absent, and Spotlight exact-name search found no matching required desktop PNGs. A bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors and found no required `desktop-*.png` files. A fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.

| Desktop Reference | Compare Against Simulator Evidence | Rows Covered |
| --- | --- | --- |
| `references/desktop-chat-list.png` | `test-artifacts/phase-1-codex-clone-20260508/paired-chat-list.jpg` | Paired chat list |
| `references/desktop-chat-list.png` | `test-artifacts/phase-1-codex-clone-20260508/empty-chat-list.jpg` | Empty chat list |
| `references/desktop-chat-list.png` | `test-artifacts/phase-1-codex-clone-20260508/disconnected-mac.jpg` | Disconnected Mac |
| `references/desktop-chat-list.png` | `test-artifacts/phase-1-codex-clone-20260508/reconnecting.jpg` | Reconnecting |
| `references/desktop-search.png` | `test-artifacts/phase-1-codex-clone-20260508/search-chats.jpg` | Search chats |
| `references/desktop-new-chat.png` | `test-artifacts/phase-1-codex-clone-20260508/new-chat.jpg` | New chat |
| `references/desktop-new-chat.png` | `test-artifacts/phase-1-codex-clone-20260508/new-chat-project-menu.jpg` | New chat project menu |
| `references/desktop-active-thread.png` | `test-artifacts/phase-1-codex-clone-20260508/approval-required-active-thread.jpg` | Active chat thread |
| `references/desktop-active-thread.png` | `test-artifacts/phase-1-codex-clone-20260508/completed-chat-thread.jpg` | Completed chat thread |
| `references/desktop-active-thread.png` | `test-artifacts/phase-1-codex-clone-20260508/focused-composer.jpg` | Focused composer |
| `references/desktop-file-artifact.png` | `test-artifacts/phase-1-codex-clone-20260508/completed-chat-thread.jpg` | File artifact |
| `references/desktop-running-thinking.png` | `test-artifacts/phase-1-codex-clone-20260508/running-thinking.jpg` | Codex running/thinking |
| `references/desktop-running-thinking.png` | `test-artifacts/phase-1-codex-clone-20260508/sending-input.jpg` | Sending input |
| `references/desktop-running-thinking.png` | `test-artifacts/phase-1-codex-clone-20260508/stop-codex.jpg` | Stop Codex |
| `references/desktop-approval-required.png` | `test-artifacts/phase-1-codex-clone-20260508/approval-required.jpg` | Approval required |
| `references/desktop-approval-required.png` | `test-artifacts/phase-1-codex-clone-20260508/approve-flow.jpg` | Approve flow |
| `references/desktop-approval-required.png` | `test-artifacts/phase-1-codex-clone-20260508/deny-flow.jpg` | Deny flow |
| `references/desktop-approval-result.png` | `test-artifacts/phase-1-codex-clone-20260508/approval-result.jpg` | Approval result |
| `references/desktop-approval-result.png` | `test-artifacts/phase-1-codex-clone-20260508/deny-result.jpg` | Denial result |
| `references/desktop-diff-artifact.png` | `test-artifacts/phase-1-codex-clone-20260508/diff-artifact.jpg` | Diff artifact |
| `references/desktop-error.png` | `test-artifacts/phase-1-codex-clone-20260508/error-state.jpg` | Error state |
| `references/desktop-settings-menu.png` | `test-artifacts/phase-1-codex-clone-20260508/overflow-menu.jpg` | Overflow menu |
| `references/desktop-settings-menu.png` | `test-artifacts/phase-1-codex-clone-20260508/settings.jpg` | Settings |
| `references/desktop-settings-menu.png` | `test-artifacts/phase-1-codex-clone-20260508/automations.jpg` | Automations |
| `references/desktop-settings-menu.png` | `test-artifacts/phase-1-codex-clone-20260508/alerts-attention.jpg` | Alerts/attention |

Handrail-only rows do not need desktop comparison:

- `unpaired-first-launch.jpg`
- `empty-unpaired-first-launch.jpg`
- `qr-pairing.jpg`
- `pairing-success.jpg`
- `pairing-management.jpg`
- `local-network-help.jpg`

Completion rule: every mapped comparison must be reviewed before any `REFERENCE BLOCKED` row in `clone-matrix.md` can move to `PASS`.
