# Architect Report

## Strongest Structural Finding

Desktop IPC and app-server request correlation had one remaining nondeterministic edge. `docs/spec/codex-desktop-ipc-protocol.md` already required deterministic IPC `requestId` values, but `cli/src/codexDesktopIpc.ts` still generated random UUID-backed IPC and app-server ids when callers did not supply an id.

The fix makes request ids auditable from the emitted request stream: IPC requests use a per-client `handrail-ipc-N` counter, app-server `initialize` keeps the fixed `__codex_initialize__` id, and later app-server requests use a per-client `<method>:N` counter.

## Invariants Preserved Or At Risk

Preserved:

- CLI and iOS protocol contracts were not widened.
- Codex Desktop remains the source of truth for visible chat metadata.
- Handrail still uses Desktop IPC for owner-routed visible-thread mutations and the Desktop app-server for new-thread app-server operations.
- Request correlation now follows one narrow deterministic path instead of relying on randomness.
- Raw Codex identifiers were not introduced into user-facing titles or notification text.

At risk:

- #2 and #3 remain structurally linked: approval routing is still blocked until live Desktop/app-server events provide real pending request ids and kinds.

Slack inbox:

- Checked `#handrail-agents` (`C0B0K6B0T6K`) for messages addressed to `Handrail Architect`.
- No message was addressed to `Handrail Architect`.
- Recent no-action coordination message: Subject `Slack coordination layer verification`, TS `1777590711.698899`, addressed to `Handrail agents`.

## Code Or Issue Changes

Repo file changes:

- `cli/src/codexDesktopIpc.ts`: removed random UUID request id generation; IPC and app-server clients now use deterministic per-client counters for requests that do not have an explicit id.
- `docs/spec/codex-desktop-app-server.md`: documented Handrail app-server request id behavior and the request-correlation invariant.
- `docs/team/outputs/architect.md`: updated this report.

GitHub issue changes:

- No GitHub issue was created or updated. Existing issues #2 and #3 already record the approval/live-event boundary; this run produced a smaller direct code/spec correction.

No Lead Dev handoff. The deterministic request id correction was narrow enough for this architect run and passed CLI verification.

## Required Design Decision

No product decision is required. Deterministic local request correlation preserves the existing local-first Codex Desktop-only contract.

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
- Read issue #2 comments and issue #3 state using local `gh`.
- Reviewed `README.md`, `docs/product-invariants.md`, `docs/spec/handrail-websocket-protocol.md`, `docs/spec/codex-desktop-ipc-protocol.md`, `docs/spec/codex-desktop-app-server.md`, `cli/src/codexDesktopIpc.ts`, `cli/src/chats.ts`, `cli/src/server.ts`, `cli/src/types.ts`, and `cli/test/codex.test.ts`.
- `npm test` in `cli/`: passed 40/40.
- `git diff --check`: passed.
- No iOS simulator validation was required because this run did not touch visible iPhone or iPad UI behavior.
