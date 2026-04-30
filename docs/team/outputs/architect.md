# Architect Report

## Strongest Structural Finding

The architect role must own the written contracts. A protocol or persistence boundary is only stable if the spec/design docs are maintained alongside the code and enforced with deterministic checks (tests or probes). This run makes that responsibility explicit in the architect persona and sets a narrow issue-filing threshold for best-practice violations.

## Invariants Preserved Or At Risk

Preserved (implementation + spec agree):

- Codex Desktop remains the source of truth for visible chat metadata (Handrail reads Desktop SQLite + rollout).
- Conversation mutation belongs to the Desktop owner renderer (Handrail opens `codex://threads/<id>` then sends `thread-follower-start-turn`).
- Raw Codex identifiers should not leak into user-visible labels (chat title fallback logic avoids UUID-like titles; notification labels do the same).

At risk (open issues / incomplete surface):

- “One observable protocol contract” between CLI and iOS: iOS currently maps unknown `ServerMessage.type` values to `.ignored`, hiding protocol drift during development (issue #18).
- Notification suppression depends on receiver attention but the CLI has no authoritative “currently viewed chat id” signal from iOS yet (issue #10).
- Approval routing is explicitly not implemented in `cli/src/chats.ts` even though the Desktop IPC surface exists for approval decisions (issue #2).

## Code Or Issue Changes

Code changes:

- Updated `cli/src/codexDesktopIpc.ts` to use `/tmp/codex-ipc/ipc-{uid}.sock` (spec-aligned).
- Added a unit test in `cli/test/codex.test.ts` asserting the observed socket path contract.

Doc stewardship changes:

- Updated `docs/team/architect.md` to make the architect responsible for creating and maintaining technical specs + design docs, keeping them updated as requirements evolve, and filing GitHub issues for concrete violations.
- Updated `docs/spec/README.md` to state the “living contract” rule for spec maintenance.
- Updated `docs/spec/codex-desktop-ipc-protocol.md` to reflect the observed `/tmp/codex-ipc/ipc-{uid}.sock` socket path contract.

Relevant open issues reviewed:

- #18 unknown server message types are silently ignored (protocol drift visibility)
- #10 active-chat notification suppression
- #2 first-class approval routing
- #3 ingest live Codex app-server events (read model enrichment without breaking Desktop parity)

## Required Design Decision

Pick the narrowest contract for “live state” beyond persistence:

- Option A (minimal): keep SQLite+rollout as the only source of truth; use app-server events only as an ephemeral overlay for *currently-running* threads, and only when the thread is already visible in Desktop’s thread list.
- Option B (broader): rely on app-server events for transcript/status for all threads and treat persistence reads as fallback.

The architect recommendation is Option A because it preserves the invariant that Handrail is an observer of Desktop-owned threads rather than a second chat authority.

## Verification

- CLI unit tests passed: `npm test` in `cli/` (includes the new IPC socket path assertion).
- No iOS simulator validation performed (no iOS UI or runtime behavior changed in this run).
