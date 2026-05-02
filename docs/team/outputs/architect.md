# Architect Report

## Strongest Structural Finding

Approval routing has moved from a blocked conceptual boundary to a narrow implemented CLI contract for Handrail-started Codex Desktop turns, but the public README and WebSocket spec still described the older heuristic transcript-detection model.

The current invariant is now sharper: `approvalId` is the structured Codex app-server request id. Handrail does not infer approval actions from transcript text, and stale or unknown ids fail visibly.

## Invariants Preserved Or At Risk

Preserved:

- Codex Desktop remains the source of truth for visible chat metadata.
- CLI and iOS still share one explicit WebSocket approval contract.
- Approval actions route only through structured local Codex Desktop/app-server request ids.
- Raw Codex identifiers were not introduced into user-facing titles or notification text.
- The CLI build/test path now starts from a clean `dist` tree, so deleted TypeScript tests cannot pass through stale compiled output.

At risk:

- #2 still lacks live approval-producing evidence from a running rebuilt Handrail server and simulator-connected approval workflow.
- #24 and #28 remain blocked on that live approval evidence; fixture or transcript-derived approval state is not enough.

Slack inbox:

- Checked `#handrail-agents` (`C0B0K6B0T6K`) for messages addressed to `Handrail Architect`.
- No message was addressed to `Handrail Architect`.
- Recent no-action coordination message: Subject `Slack coordination layer verification`, TS `1777590711.698899`, addressed to `Handrail agents`.

## Code Or Issue Changes

Repo file changes:

- `README.md`: replaced the regex-pattern approval description with the implemented structured app-server approval request-id contract.
- `docs/spec/handrail-websocket-protocol.md`: updated the approval routing boundary to match `cli/src/chats.ts` and `cli/src/codexDesktopIpc.ts`.
- `cli/src/approvals.ts`: removed the unused transcript approval detector.
- `cli/test/approvals.test.ts`: removed the detector-only test because no production code imports that detector.
- `cli/package.json`: made `npm run build` remove `dist` before compiling so `npm test` cannot execute stale deleted tests.
- `docs/team/outputs/architect.md`: updated this report.

GitHub issue changes:

- No GitHub issue was created or updated. Issue #2 already records the remaining live approval evidence blocker, and this run corrected repo contract drift directly.

No Lead Dev handoff. The correction was narrow, implemented, and verified in this architect run.

## Required Design Decision

No product decision is required. The run preserves the existing local-first Codex Desktop-only contract and narrows approval routing to structured local app-server requests.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found.

## Verification

- Read architect automation memory.
- Read `docs/team/architect.md` and `docs/team/README.md`.
- Checked `$CODEX_HOME/automations/handrail-architect/handoff.md`; no handoff note was present.
- Read `#handrail-agents` (`C0B0K6B0T6K`) through the Slack connector.
- Verified `gh auth status -h github.com` is authenticated as `zfifteen`.
- Read open GitHub issues with `gh issue list --repo zfifteen/handrail --state open --limit 80`.
- Read issue #2 and #3 with comments using local `gh`.
- Reviewed `README.md`, `docs/product-invariants.md`, `docs/spec/README.md`, `docs/spec/handrail-websocket-protocol.md`, `docs/spec/codex-desktop-ipc-protocol.md`, `docs/spec/codex-desktop-app-server.md`, `cli/src/chats.ts`, `cli/src/codexDesktopIpc.ts`, `cli/src/types.ts`, `cli/src/approvals.ts`, `cli/test/approvals.test.ts`, `cli/test/codex.test.ts`, `docs/team/outputs/qa-lead.md`, and `docs/team/outputs/lead-dev.md`.
- Initial `npm test` in `cli/` exposed stale compiled `dist/test/approvals.test.js` after source deletion, so `cli/package.json` now cleans `dist` in `npm run build`.
- Final `npm test` in `cli/`: passed 43/43.
- `git diff --check`: passed.
- No iOS simulator validation was required because this run did not touch visible iPhone or iPad UI behavior.
