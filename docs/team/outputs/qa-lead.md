# QA Lead Report

## Strongest Evidence Finding

The approval-routing source still passes the full 44-test CLI suite, including the approval-state `chat_list` broadcast contract, but live QA still cannot validate #2 or close #24 because the running Handrail LaunchAgent server remains stale. On 2026-05-04T00:45Z, the listener was still `node` PID `4657`; `launchctl kickstart -k gui/501/com.velocityworks.handrail.server` returned `Operation not permitted`; the listener remained PID `4657`; and the live `chats` probe showed no `waiting_for_approval` row.

## Verified Behavior

- Slack `#handrail-agents` (`C0B0K6B0T6K`) had no new message addressed to `Handrail QA Lead`.
  - Ignored no-action message to `Handrail agents`.
  - Slack Subject: `Slack coordination layer verification`.
  - Slack timestamp: `1777590711.698899`.
- `$CODEX_HOME/automations/handrail-qa-lead/handoff.md` still points QA at #24 only after #2 produces a real live `waiting_for_approval` state.
- `gh auth status` is authenticated as `zfifteen`; GitHub reads used local `gh`.
- Open issues still show #2 and #24 as blocked; #24 remains dependent on #2 live approval evidence.
- `npm test` in `cli/` rebuilt `cli/dist` and passed 44/44, including `chat manager broadcasts chat list when approval state changes`.
- `node cli/dist/src/index.js chats` showed running, idle, and completed chats only; no `waiting_for_approval` row exists.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN` showed the live server listener before restart as `node` PID `4657`.
- `launchctl kickstart -k gui/501/com.velocityworks.handrail.server` failed with `Operation not permitted`.
- The listener stayed on `node` PID `4657` after the restart attempt.
- `launchctl print gui/501/com.velocityworks.handrail.server` confirmed the LaunchAgent is still running `/usr/local/bin/node /Users/velocityworks/IdeaProjects/handrail/cli/dist/src/index.js serve` as PID `4657`.

## Missing Evidence Or Regressions

- #2 remains open because QA still has no live approval-producing Handrail-started Codex turn through the running local server.
- #24 remains open because the iPad Dashboard closure evidence requires a real simulator-connected `waiting_for_approval` row, live chat id, and screenshot; fixture state and test-only launch injection remain excluded.
- No iPad simulator validation was run in this pass because the selected UI issue cannot be exercised without live approval state, and the run stopped at the stale-server gate required by the handoff.

## Code, Test, Or Issue Changes

- Updated this QA report with the current 44-test result and unchanged LaunchAgent blocker.
- Updated `$CODEX_HOME/automations/handrail-qa-lead/handoff.md` with the same blocker.
- Did not add a duplicate GitHub comment because #2 and #24 already contain the same PID `4657` restart blocker and no new live evidence was produced.
- No product source code was edited by QA.
- Existing unrelated local changes were preserved.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found. This run inspected local CLI, local LaunchAgent state, local server output, Slack, GitHub issue state, and project validation docs only.

## Verification

- `sed -n '1,260p' docs/team/qa-lead.md`: inspected.
- `sed -n '1,260p' docs/team/README.md`: inspected.
- Slack read: `#handrail-agents` channel `C0B0K6B0T6K`, no addressed message to `Handrail QA Lead`.
- `test -f $CODEX_HOME/automations/handrail-qa-lead/handoff.md && sed -n '1,220p' ...`: inspected.
- `gh auth status`: authenticated as `zfifteen`.
- `gh issue list -R zfifteen/handrail --state open --limit 100`: inspected open issues.
- `gh issue view -R zfifteen/handrail 2 --comments`: inspected #2 implementation and blocker history.
- `gh issue view -R zfifteen/handrail 24 --comments`: inspected #24 closure requirements.
- `sed -n '1,220p' TEST_PLAN.md`: inspected.
- `sed -n '1,220p' docs/product-invariants.md`: inspected.
- `sed -n '1,220p' UI_PATHS.md`: inspected.
- `sed -n '1,220p' UI_PATH_ISSUES.md`: inspected.
- `npm test` in `cli/`: passed 44/44.
- `node cli/dist/src/index.js chats`: inspected current live Desktop-visible chat states; no `waiting_for_approval`.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN`: listener stayed on PID `4657`.
- `launchctl kickstart -k gui/501/com.velocityworks.handrail.server`: failed with `Operation not permitted`.
- `launchctl print gui/501/com.velocityworks.handrail.server | sed -n '1,120p'`: confirmed LaunchAgent PID `4657` and serve command.
