# Architect Report

## Strongest Structural Finding

App-server approval and live-event callbacks could reach iOS before the newly started `codex:` thread had appeared in Handrail's Desktop-derived chat list. The start-chat path already waited for Desktop visibility before broadcasting `chat_started`; this run extended the same no-orphan invariant to app-server approval requests and live events.

## Invariants Preserved Or At Risk

- Codex Desktop remains the source of truth for visible chat rows: improved. `approval_required`, approval `chat_event`, and app-server live `chat_event` output now wait for `listCodexChats()` to expose the matching `codex:<threadId>`.
- CLI and iOS share one observable protocol contract: improved. The WebSocket and app-server specs now state the visibility gate explicitly.
- Raw Codex identifiers must not leak into titles or notification text: no change.
- Spec documents must describe observed behavior and avoid unsupported Desktop guarantees: preserved. The new language describes Handrail-owned gating, not a new upstream guarantee.

## Code Or Issue Changes

- Updated `cli/src/chats.ts` so app-server approval requests and live events wait for the Desktop-visible chat before emitting mobile protocol state.
- Updated `cli/src/chats.ts` so async callback failures are broadcast as explicit WebSocket `error` messages instead of becoming unhandled async work.
- Added `app-server approval requests wait for Desktop visibility before mobile broadcast` in `cli/test/codex.test.ts`.
- Updated `docs/spec/handrail-websocket-protocol.md` and `docs/spec/codex-desktop-app-server.md` with the app-server visibility gate.
- Slack `#handrail-agents` (`C0B0K6B0T6K`) had no message addressed to `Handrail Architect`; ignored the no-action verification message with Slack Subject `Slack coordination layer verification` and timestamp `1777590711.698899`.
- Updated GitHub issue #2 with the architect note for this no-orphan protocol correction.
- No Lead Dev handoff. The narrow patch is complete in this run; #2 remains blocked on live LaunchAgent replacement and real approval-producing Desktop evidence.

## Required Design Decision

No new product decision is required. #2 remains a live-evidence blocker: closure still needs the running local server to expose the rebuilt CLI, then one real approval-producing Handrail-started Codex Desktop/app-server turn with iOS approve/deny evidence against the app-server request id.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found. The change is local CLI protocol behavior plus specs/tests; it does not add cloud relay, account state, payment, generic terminal behavior, multi-agent control, non-Codex support, or direct iOS file editing.

## Verification

- `sed -n '1,240p' docs/team/architect.md`: inspected.
- `sed -n '1,240p' docs/team/README.md`: inspected.
- Automation memory inspected at `$CODEX_HOME/automations/handrail-architect/memory.md`; no architect handoff file was present.
- Slack read of `#handrail-agents` (`C0B0K6B0T6K`): no `To: Handrail Architect` request found.
- `gh auth status -h github.com`: authenticated as `zfifteen`.
- `gh issue list --repo zfifteen/handrail --state open --limit 50`: inspected current open blockers.
- `gh issue view 2 --repo zfifteen/handrail --comments`: inspected approval-routing state.
- `gh issue view 24 --repo zfifteen/handrail --comments`: inspected dependent iPad closure blocker.
- `npm test` in `cli/`: passed 45/45.
- `git diff --check`: passed.
- No iPhone/iPad simulator validation was run because this run did not change visible iOS UI, navigation, decoded iOS screen data, gestures, sheets, tabs, lists, or empty states.
