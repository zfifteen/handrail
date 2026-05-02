# Architect Report

## Strongest Structural Finding

The approval-routing contract now preserves one shared observable state transition: when the CLI records a structured app-server approval request, it emits `approval_required`, `chat_event`, and a refreshed `chat_list` with the Desktop-visible chat overlaid as `waiting_for_approval`. Before this run, the iOS store compensated for the direct approval message, but the WebSocket protocol itself did not broadcast the list mutation at the point where approval state changed.

## Invariants Preserved Or At Risk

- Codex Desktop remains the source of truth for visible chat rows: preserved. The new `chat_list` broadcast is still built from `listCodexChats()` and `applyPendingApprovals()`, so the approval overlay cannot create a mobile-only chat.
- CLI and iOS share one observable protocol contract: improved. Approval state now has an explicit list-broadcast contract instead of depending on iOS-only local mutation.
- Raw Codex identifiers must not leak into titles or notification text: no change.
- Spec documents must describe observed behavior and avoid unsupported Desktop guarantees: updated to describe the Handrail-owned broadcast contract only.

## Code Or Issue Changes

- Updated `cli/src/chats.ts` so `handleDesktopApprovalRequest` broadcasts a refreshed `chat_list` after storing a pending approval.
- Added `chat manager broadcasts chat list when approval state changes` in `cli/test/codex.test.ts`.
- Updated `docs/spec/handrail-websocket-protocol.md` and `docs/spec/codex-desktop-app-server.md` with the approval-state list-broadcast contract.
- Slack `#handrail-agents` (`C0B0K6B0T6K`) had no message addressed to `Handrail Architect`; ignored the no-action verification message with Slack Subject `Slack coordination layer verification` and timestamp `1777590711.698899`.
- Updated GitHub issue #2 with the architect note for this protocol correction.

## Required Design Decision

No new product decision is required. #2 remains blocked on live Desktop/app-server approval evidence because the running LaunchAgent server still needs to be replaced before QA can exercise a real approval-producing Handrail-started turn. This run did not close or reclassify that blocker.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found. The change is local CLI protocol behavior plus specs/tests; it does not add cloud relay, account state, payment, generic terminal behavior, multi-agent control, non-Codex support, or direct iOS file editing.

## Verification

- `sed -n '1,240p' docs/team/architect.md`: inspected.
- `sed -n '1,240p' docs/team/README.md`: inspected.
- Slack read of `#handrail-agents` (`C0B0K6B0T6K`): no `To: Handrail Architect` request found.
- `gh auth status`: authenticated as `zfifteen` for local `gh` access.
- `gh issue list --repo zfifteen/handrail --state open --limit 50`: inspected current open blockers.
- `gh issue view 2 --repo zfifteen/handrail --comments`: inspected approval-routing state.
- `gh issue view 24 --repo zfifteen/handrail --comments`: inspected dependent iPad closure blocker.
- `npm test` in `cli/`: passed 44/44.
- `git diff --check`: passed.
- No iPhone/iPad simulator validation was run because this run did not change visible iOS UI, navigation, decoded iOS screen data, gestures, sheets, tabs, lists, or empty states.
