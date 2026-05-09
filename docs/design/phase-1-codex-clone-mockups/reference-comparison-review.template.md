# Reference Comparison Review Template

Do not rename this template to `reference-comparison-review.md` until every required desktop reference screenshot exists and every mapped comparison in `reference-comparison-map.md` has been reviewed.

Current blocker as of the 2026-05-08 21:53 EDT inspection: `references/` contains only `BLOCKED.md`; all eleven required `desktop-*.png` files are absent, `reference-comparison-review.md` is absent, and Spotlight exact-name search found no matching required desktop PNGs. A bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors and found no required `desktop-*.png` files. A fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.

The completed review must include a nonblank date and reviewer, must replace the blank template bullets below with concrete findings and required corrections content, and must remove this template instruction text.

Date:

Reviewer:

Decision: PASS.

Use exactly `Decision: PASS.` only after every mapped comparison passes. Any other decision text fails `verify-evidence.sh`.

QC hard rejection review: PASS.

Use exactly `QC hard rejection review: PASS.` only after the reviewer confirms `qc-checklist.md` has no hard rejection item in the implemented iPhone evidence.

Reviewed inputs:

- `docs/design/phase-1-codex-clone-mockups/reference-comparison-map.md`
- `docs/design/phase-1-codex-clone-mockups/index.html`
- `docs/design/phase-1-codex-clone-mockups/clone-matrix.md`
- `docs/design/phase-1-codex-clone-mockups/qc-checklist.md`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-chat-list.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-new-chat.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-active-thread.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-running-thinking.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-approval-required.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-approval-result.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-file-artifact.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-diff-artifact.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-error.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-search.png`
- `docs/design/phase-1-codex-clone-mockups/references/desktop-settings-menu.png`
- `test-artifacts/phase-1-codex-clone-20260508/paired-chat-list.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/empty-chat-list.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/disconnected-mac.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/reconnecting.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/search-chats.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/new-chat.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/new-chat-project-menu.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/approval-required-active-thread.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/completed-chat-thread.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/focused-composer.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/running-thinking.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/sending-input.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/stop-codex.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/approval-required.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/approve-flow.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/deny-flow.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/approval-result.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/deny-result.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/diff-artifact.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/error-state.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/overflow-menu.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/settings.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/automations.jpg`
- `test-artifacts/phase-1-codex-clone-20260508/alerts-attention.jpg`

Comparison rows reviewed:

Each mapped row must use `PASS` in the Result column before the review decision can be `PASS`.

| Desktop reference | Simulator evidence | Screen | Result |
| --- | --- | --- | --- |
| `references/desktop-chat-list.png` | `paired-chat-list.jpg` | Paired chat list |  |
| `references/desktop-chat-list.png` | `empty-chat-list.jpg` | Empty chat list |  |
| `references/desktop-chat-list.png` | `disconnected-mac.jpg` | Disconnected Mac |  |
| `references/desktop-chat-list.png` | `reconnecting.jpg` | Reconnecting |  |
| `references/desktop-search.png` | `search-chats.jpg` | Search chats |  |
| `references/desktop-new-chat.png` | `new-chat.jpg` | New chat |  |
| `references/desktop-new-chat.png` | `new-chat-project-menu.jpg` | New chat project menu |  |
| `references/desktop-active-thread.png` | `approval-required-active-thread.jpg` | Active chat thread |  |
| `references/desktop-active-thread.png` | `completed-chat-thread.jpg` | Completed chat thread |  |
| `references/desktop-active-thread.png` | `focused-composer.jpg` | Focused composer |  |
| `references/desktop-file-artifact.png` | `completed-chat-thread.jpg` | File artifact |  |
| `references/desktop-running-thinking.png` | `running-thinking.jpg` | Codex running/thinking |  |
| `references/desktop-running-thinking.png` | `sending-input.jpg` | Sending input |  |
| `references/desktop-running-thinking.png` | `stop-codex.jpg` | Stop Codex |  |
| `references/desktop-approval-required.png` | `approval-required.jpg` | Approval required |  |
| `references/desktop-approval-required.png` | `approve-flow.jpg` | Approve flow |  |
| `references/desktop-approval-required.png` | `deny-flow.jpg` | Deny flow |  |
| `references/desktop-approval-result.png` | `approval-result.jpg` | Approval result |  |
| `references/desktop-approval-result.png` | `deny-result.jpg` | Denial result |  |
| `references/desktop-diff-artifact.png` | `diff-artifact.jpg` | Diff artifact |  |
| `references/desktop-error.png` | `error-state.jpg` | Error state |  |
| `references/desktop-settings-menu.png` | `overflow-menu.jpg` | Overflow menu |  |
| `references/desktop-settings-menu.png` | `settings.jpg` | Settings |  |
| `references/desktop-settings-menu.png` | `automations.jpg` | Automations |  |
| `references/desktop-settings-menu.png` | `alerts-attention.jpg` | Alerts/attention |  |

Findings:

- Replace with concrete findings.

Required corrections:

- Replace with concrete required corrections, or state that no corrections are required.
