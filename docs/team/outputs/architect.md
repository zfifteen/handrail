# Architect Report

## Strongest Structural Finding

Approval routing was keyed too narrowly inside the CLI. The mobile protocol sends `chatId` plus `approvalId`, and `approvalId` is the raw Codex app-server request id. That request id is only scoped to one retained app-server child process, so two simultaneous Handrail-started chats could both receive `server-request-1`; the old `pendingApprovals` map would let the later request overwrite the earlier one.

## Invariants Preserved Or At Risk

- CLI and iOS share one observable protocol contract: improved. The implementation now stores pending approvals by the same tuple iOS sends back: `chatId` plus `approvalId`.
- Approval actions route a real Desktop pending request id: preserved. The public `approvalId` remains the app-server request id; no local UUID or transcript-derived id was introduced.
- Codex Desktop remains the source of truth for visible chat rows: preserved. The change only affects pending approval routing after the Desktop-visible chat gate.
- Spec documents describe observed behavior without overstating Desktop guarantees: improved. The specs now state that app-server request ids are not globally unique across independent retained app-server children.
- Raw Codex identifiers must not leak into user-facing titles or notification text: no change.

## Code Or Issue Changes

- Updated `cli/src/chats.ts` so pending approvals are inserted, looked up, and deleted by `chatId` plus `approvalId`.
- Added `chat manager scopes duplicate approval ids by chat id` in `cli/test/codex.test.ts`.
- Updated `docs/spec/codex-desktop-app-server.md` with the app-server request-id scoping rule.
- Updated `docs/spec/handrail-websocket-protocol.md` with the approval route key: `chatId + approvalId`.
- Slack `#handrail-agents` (`C0B0K6B0T6K`) had no message addressed to `Handrail Architect`; ignored the no-action verification message with Slack Subject `Slack coordination layer verification` and timestamp `1777590711.698899`.
- Updated GitHub issue #2 with the duplicate-request-id scoping correction and remaining live evidence gate.
- No Lead Dev handoff. The narrow architecture patch is complete in this run; #2 still needs live server replacement and real approval-producing Desktop/iOS evidence.

## Required Design Decision

No new product decision is required. #2 remains a live-evidence blocker: closure still needs the running LaunchAgent server to expose the rebuilt CLI, then one real approval-producing Handrail-started Codex Desktop/app-server turn with iOS approve/deny evidence against the app-server request id.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found. The change is local CLI approval routing plus specs/tests; it does not add cloud relay, account state, payment, generic terminal behavior, multi-agent control, non-Codex support, or direct iOS file editing.

## Verification

- Automation memory inspected at `$CODEX_HOME/automations/handrail-architect/memory.md`.
- No architect handoff file was present at `$CODEX_HOME/automations/handrail-architect/handoff.md`.
- `sed -n '1,260p' docs/team/architect.md`: inspected.
- `sed -n '1,260p' docs/team/README.md`: inspected.
- Slack read of `#handrail-agents` (`C0B0K6B0T6K`): no `To: Handrail Architect` request found.
- `gh auth status --hostname github.com`: authenticated as `zfifteen`.
- `gh issue list --repo zfifteen/handrail --state open --limit 60`: inspected current open blockers.
- `gh issue view 2 --repo zfifteen/handrail --comments`: inspected approval-routing state.
- `npm test` in `cli/`: passed 46/46.
- `git diff --check`: passed.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN`: LaunchAgent server still listening as `node` PID `4657`.
- `launchctl print gui/501/com.velocityworks.handrail.server`: service is running `/Users/velocityworks/IdeaProjects/handrail/cli/dist/src/index.js serve` as PID `4657`.
- No iPhone/iPad simulator validation was run because this run did not change visible iOS UI, navigation, decoded iOS screen data, gestures, sheets, tabs, lists, or empty states.
