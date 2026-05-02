# Architect Report

## Strongest Structural Finding

The app-server spec had drifted from the current #29 implementation contract. New chat creation now uses the Codex Desktop app-server for both `thread/start` and the first `turn/start` on one retained app-server connection; Desktop IPC `thread-follower-start-turn` remains the route for continuing an existing Desktop-visible thread.

## Invariants Preserved Or At Risk

Preserved:

- Handrail remains a local-first observer/controller for Codex Desktop, not a separate chat authority.
- A phone-created chat must not become mobile-visible until the Desktop-derived read model exposes the new `codex:` id.
- Existing Desktop-visible chat continuation still goes through the Desktop owner route.
- Raw Codex identifiers were not introduced into user-facing titles or notification text.

At risk:

- #29 remains acceptance-blocked because the live listener on `127.0.0.1:8788` is still running pre-patch code, while a patched ephemeral server reaches Codex app-server session access and then fails at the automation sandbox boundary.

Slack inbox:

- Checked `#handrail-agents` (`C0B0K6B0T6K`) for messages addressed to `Handrail Architect`.
- No message was addressed to `Handrail Architect`.
- Recent no-action coordination message: Subject `Slack coordination layer verification`, TS `1777590711.698899`, addressed to `Handrail agents`.

## Code Or Issue Changes

Repo file changes:

- `docs/spec/codex-desktop-app-server.md`: aligned the living app-server contract with the current implementation and #29 evidence:
  - documented app-server `turn/start`;
  - documented app-server `turn/completed` retention;
  - separated new-chat app-server startup from existing-thread Desktop IPC continuation;
  - recorded the no-orphan `chat_started` / `chat_event` / `chat_list` broadcast invariant.
- `docs/team/outputs/architect.md`: updated this report.

GitHub issue changes:

- No GitHub issue was created or updated. Issue #29 already records the live acceptance blocker and the needed out-of-sandbox server restart.

No Lead Dev handoff. The implementation contract already has focused CLI tests; the missing action is operational validation of the restarted live server, not a new patch target.

## Required Design Decision

No product decision is required. The existing product contract is sufficient: app-server thread creation remains local Codex Desktop integration, and mobile visibility is gated by the Desktop-derived chat list.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found.

## Verification

- Read architect automation memory.
- Read `docs/team/architect.md` and `docs/team/README.md`.
- Checked `$CODEX_HOME/automations/handrail-architect/handoff.md`; no handoff note was present.
- Read `#handrail-agents` (`C0B0K6B0T6K`) through the Slack connector.
- Verified `gh auth status -h github.com` is authenticated as `zfifteen`.
- Read open GitHub issues with `gh issue list --repo zfifteen/handrail --state open --limit 40`.
- Read issue #29 with comments using local `gh issue view 29 --repo zfifteen/handrail --comments`.
- Reviewed `README.md`, `docs/product-invariants.md`, `docs/spec/README.md`, `docs/spec/handrail-websocket-protocol.md`, `docs/spec/codex-desktop-ipc-protocol.md`, `docs/spec/codex-desktop-app-server.md`, `docs/spec/codex-desktop-persistence.md`, `cli/src/codexDesktopIpc.ts`, and `cli/test/codex.test.ts`.
- `npm test` in `cli/`: passed 40/40.
- `git diff --check`: passed.
- No iOS simulator validation was required because this run changed a spec/report only and did not touch visible iPhone or iPad UI behavior.
