# QA Lead Report

## Strongest Evidence Finding

The #2/#24 approval validation gate is still blocked by the unchanged LaunchAgent listener. The rebuilt CLI passed 46/46 tests, but the live Handrail server on `127.0.0.1:8788` stayed on `node` PID `4657` after the prescribed `launchctl kickstart -k` attempt, and the live chat list still contains no `waiting_for_approval` row.

## Verified Behavior

- Slack `#handrail-agents` (`C0B0K6B0T6K`) had no recent message addressed to `Handrail QA Lead`; the only channel request remains the no-action verification with Subject `Slack coordination layer verification` at TS `1777590711.698899`.
- `gh auth status -h github.com` is authenticated as `zfifteen`; GitHub reads used local `gh` only.
- Open issue state is unchanged for QA selection: #2 and #24 remain labeled `blocked`, with #24 dependent on #2 live approval evidence.
- `npm test` in `cli/` rebuilt `cli/dist` and passed 46/46, including the approval request-id routing, Desktop-visible broadcast gate, approval-state `chat_list` broadcast, and duplicate request-id scoping tests.
- Before restart, `lsof -nP -iTCP:8788 -sTCP:LISTEN` showed `node` PID `4657`.
- `node cli/dist/src/index.js chats` showed running, idle, and completed chats only; no `waiting_for_approval` row existed.
- `launchctl print gui/501/com.velocityworks.handrail.server` showed `/usr/local/bin/node /Users/velocityworks/IdeaProjects/handrail/cli/dist/src/index.js serve` running as PID `4657`.

## Missing Evidence Or Regressions

- `launchctl kickstart -k gui/501/com.velocityworks.handrail.server` returned `Operation not permitted`.
- After the restart attempt, `lsof -nP -iTCP:8788 -sTCP:LISTEN` still showed `node` PID `4657`, and `launchctl print` still reported PID `4657`.
- #2 cannot be closed until the running server is replaced or otherwise exposes the rebuilt CLI, then produces one real approval-producing Handrail-started Codex Desktop/app-server turn with approve/deny evidence against the app-server request id.
- #24 cannot be closed until that same live feed contains a simulator-visible `waiting_for_approval` row on iPad Dashboard.

## Code, Test, Or Issue Changes

- Updated `docs/team/outputs/qa-lead.md`.
- Updated `$CODEX_HOME/automations/handrail-qa-lead/handoff.md`.
- No product source code was edited.
- No GitHub issue comment was added because the run reproduced the same PID `4657` restart blocker already recorded on #2/#24, with no new live acceptance evidence.
- Preserved unrelated local user changes in `docs/team/outputs/business-analyst.md`, `docs/spec/handrail-notification-suppression.md`, `ios/Handrail/Handrail/Utilities/NotificationCoordinator.swift`, and `ios/Handrail/HandrailTests/HandrailCommandAvailabilityTests.swift`.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found.

## Verification

- `npm test` in `cli/`: passed 46/46.
- `gh issue list -R zfifteen/handrail --state open --limit 100 --json number,title,labels,milestone,updatedAt,url`: inspected.
- `gh issue view -R zfifteen/handrail 2 --comments`: inspected.
- `gh issue view -R zfifteen/handrail 24 --comments`: inspected.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN`: listener remained `node` PID `4657`.
- `launchctl kickstart -k gui/501/com.velocityworks.handrail.server`: failed with `Operation not permitted`.
- `launchctl print gui/501/com.velocityworks.handrail.server`: service still running as PID `4657`.
- `node cli/dist/src/index.js chats`: no `waiting_for_approval` row.
- No iPhone or iPad simulator validation was run because the selected visible iPad issue #24 still lacks the real live approval state required for closure; no UI fix was reported as fully verified.
