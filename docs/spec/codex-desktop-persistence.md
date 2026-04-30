# Codex Desktop Persistence

This document records how Handrail reads persisted Codex Desktop conversation state.

Observed Desktop build:

- App version: `26.422.71525`
- Build number: `2210`
- Bundle id: `com.openai.codex`

Related specs:

- [Codex Desktop App Server](codex-desktop-app-server.md)
- [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md)
- [Codex Desktop Refresh And Snapshots](codex-desktop-refresh-and-snapshots.md)

## Observed Sources

Observed Handrail source:

- `cli/src/codexSessions.ts`
  - `readDesktopThreads`
  - `visibleDesktopThreads`
  - `readDesktopPinnedThreadIds`
  - `readRolloutLines`
  - `readCodexSession`
  - `humanCodexTitle`

Observed Desktop files:

- `~/.codex/state_5.sqlite`
- `~/.codex/.codex-global-state.json`
- Rollout paths from the `threads.rollout_path` column

## SQLite Thread Metadata

Handrail reads:

```sql
SELECT id, rollout_path, cwd, title, created_at, updated_at, archived, source, first_user_message
FROM threads
ORDER BY updated_at DESC, id DESC
```

Visible rows are filtered to:

- `archived = 0`
- `source = "vscode"`
- non-empty `first_user_message`

Handrail keeps at most 50 records.

## Rollout Files

Observed:

- Each visible SQLite row points at a rollout file through `rollout_path`.
- Handrail expects the first rollout line to be `session_meta`.
- The session id from `session_meta.payload.id` becomes the Handrail id `codex:<id>`.
- Handrail extracts transcript, thinking entries, status, title candidates, and update timestamps from rollout lines.

For large rollouts, Handrail reads:

- the first 64 KiB, to preserve `session_meta`
- the last 2 MiB, to capture recent transcript and status

## Pinned State

Handrail reads pinned ids from:

```text
~/.codex/.codex-global-state.json
```

The key is:

```json
"pinned-thread-ids"
```

The array order becomes `pinnedOrder`.

## Title Derivation

Handrail tries title candidates in order:

1. Desktop SQLite `title`
2. rollout-derived title
3. SQLite `first_user_message`
4. repository basename

Raw UUID-like Codex identifiers are skipped for display.

## Observed Versus Inferred

Observed:

- Handrail can reconstruct a chat list from SQLite plus rollout files.
- Handrail's iOS UI can update after polling or WebSocket broadcast of that reconstructed list.

Inferred:

- Persistence is enough for eventual reconstruction.
- Persistence is not enough to guarantee an already-rendered Desktop conversation view repaints immediately.

Unknown:

- The exact Desktop renderer cache invalidation rules for a conversation already loaded in memory.
- Whether Desktop watches rollout file changes directly or only updates through app-server notifications and renderer state.

## Handrail Implication

Handrail's read model is a durable-state observer. The visible Desktop sync problem is a live-renderer problem.

The invariant is:

```text
If the rollout changes, Handrail can eventually read it; the Desktop renderer may still need an owner mutation or snapshot signal to repaint.
```

