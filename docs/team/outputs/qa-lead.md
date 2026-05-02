# QA Lead Report

## Strongest Evidence Finding

#29 is blocked before live product validation: the actual Handrail listener on `127.0.0.1:8788` is still the same stale LaunchAgent process, `node` PID `16041`, and has not been replaced since the prior failing live probes. The current local branch rebuilds and passes the CLI contract tests, but rerunning another live `start_chat` against the unchanged PID would only duplicate the known old `thread-follower-start-turn` failure.

The next valid QA action is not another failed start attempt. It is to restart LaunchAgent `com.velocityworks.handrail.server` outside this automation sandbox so PID `16041` is replaced, then rerun #29 acceptance against the real listener.

## Verified Behavior

- Slack `#handrail-agents` (`C0B0K6B0T6K`) had no message addressed to `Handrail QA Lead`.
  - Ignored no-action message to `Handrail agents`.
  - Slack Subject: `Slack coordination layer verification`.
  - Slack timestamp: `1777590711.698899`.
- `$CODEX_HOME/automations/handrail-qa-lead/handoff.md` contained only the older lead-dev automation contract note, so it did not require simulator validation.
- `gh auth status -h github.com` is authenticated as `zfifteen`; GitHub reads used local `gh`.
- Open issue review kept #29 as the highest-value QA target because #21, #22, and #24 all depend on a real successful `start_chat` or live approval state.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN` showed the live server is still `node` PID `16041`.
- `launchctl print gui/$(id -u)/com.velocityworks.handrail.server` showed:
  - state: `running`;
  - PID: `16041`;
  - program: `/usr/local/bin/node`;
  - arguments: `/Users/velocityworks/IdeaProjects/handrail/cli/dist/src/index.js serve`;
  - runs: `8`.
- `npm test` in `cli/` rebuilt `cli/dist` and passed all 40 CLI tests.
- The rebuilt `cli/dist/src/codexDesktopIpc.js` contains app-server `thread/start` and `turn/start` strings, but it also necessarily still contains the follower route for continued existing Desktop chats. The acceptance blocker is the live listener process, not the presence of follower IPC code in dist.

## Missing Evidence Or Regressions

- #29 acceptance evidence is still missing on the actual local server:
  - no fresh post-restart `chat_started`;
  - no fresh post-restart chat-linked `chat_event`;
  - no fresh post-restart matching Desktop-visible `codex:` row in `node cli/dist/src/index.js chats`.
- #21 remains blocked by #29 because iPad New Chat dismissal/routing needs a real `chat_started`.
- #22 remains blocked by #29 because iPad Activity row routing needs a real chat-linked Activity event.
- #24 remains blocked by #29 and #2 because the app still needs live `waiting_for_approval` evidence from first-class approval ingestion.
- Simulator validation was not run in this targeted pass because the selected issue is currently blocked at the local server process boundary before any new iPhone or iPad UI state exists to validate. No iPad UI fix is reported as verified.

## Code, Test, Or Issue Changes

- Updated this QA report with the current LaunchAgent/PID blocker and verification evidence.
- Updated `$CODEX_HOME/automations/handrail-qa-lead/handoff.md` so the next QA run starts from the restart gate instead of the stale coordination note.
- No product source code was changed in this QA run.
- No GitHub issue comment was added because #29 already received the same current LaunchAgent blocker evidence from Lead Dev at 2026-05-02T05:36Z, and this QA run produced no new live product signal beyond confirming the listener is still unchanged.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: no product-invariant drift found. This run preserved the local Codex Desktop ownership boundary and did not introduce cloud relay, hosted execution, account, payment, generic terminal, non-Codex agent, or iOS direct-editing behavior.

## Verification

- `sed -n '1,240p' docs/team/qa-lead.md`: inspected.
- `sed -n '1,260p' docs/team/README.md`: inspected.
- Slack read: `#handrail-agents` channel `C0B0K6B0T6K`, no addressed message to `Handrail QA Lead`.
- `gh auth status -h github.com`: authenticated as `zfifteen`.
- `gh issue list -R zfifteen/handrail --state open --limit 100`: inspected open issues.
- `gh issue view -R zfifteen/handrail 29 --comments`: inspected latest #29 evidence.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN`: confirmed unchanged listener PID `16041`.
- `launchctl print gui/$(id -u)/com.velocityworks.handrail.server`: confirmed LaunchAgent state and PID `16041`.
- `npm test` from `/Users/velocityworks/IdeaProjects/handrail/cli`: passed 40/40.
- `git diff --check`: passed.
