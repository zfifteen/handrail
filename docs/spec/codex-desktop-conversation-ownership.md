# Codex Desktop Conversation Ownership

This document records how the observed Codex Desktop build routes conversation operations to the Desktop window that owns a conversation.

Observed Desktop build:

- App version: `26.422.71525`
- Build number: `2210`
- Bundle id: `com.openai.codex`

Related specs:

- [Codex Desktop Deeplinks](codex-desktop-deeplinks.md)
- [Codex Desktop IPC Protocol](codex-desktop-ipc-protocol.md)
- [Codex Desktop Refresh And Snapshots](codex-desktop-refresh-and-snapshots.md)

## Observed Sources

Observed bundle symbols and paths:

- `webview/assets/app-server-manager-signals-w7HK0qNP.js`
  - `getStreamRole`
  - `assertThreadFollowerOwner`
  - `sendThreadFollowerRequest`
  - `markConversationNeedsResumeForUnavailableOwner`
  - `handleThreadFollowerStartTurn`
- `webview/assets/index-D-3V455n.js`
  - `thread-follower-*-for-host`
  - `targetClientId`
  - `thread-role-for-host`
- `.vite/build/main-DjuaMcIZ.js`
  - `thread-follower-*` request routing
  - `ipc-request`

Observed Handrail source:

- `cli/src/codexDesktopIpc.ts`
  - `startCodexDesktopTurn`
  - `codexDesktopFollowerTurnStartParams`
  - `CodexDesktopIpcClient`

## Ownership Model

Observed:

- Desktop tracks a per-conversation stream role.
- A conversation role can be `owner` or `follower`.
- Follower IPC methods are routed to the owner Desktop renderer.
- The renderer rejects follower actions unless `assertThreadFollowerOwner(conversationId)` passes.
- Some UI paths forward to the owner with `targetClientId`.

Inferred:

- The owner is the renderer instance whose in-memory conversation state can safely start, steer, interrupt, or edit that conversation.
- A follower can display or refer to a conversation, but it should not directly mutate turn state.
- The Desktop-visible iOS sync path must mutate the owner renderer, not only the rollout file or SQLite metadata.

Unknown:

- The full set of events that make a renderer become owner.
- Whether focusing `codex://threads/<conversationId>` always transfers ownership to the focused window.
- Whether an owner can exist without an open visible conversation view.

## Routing Contracts

External selection:

```text
codex://threads/<conversationId>
```

Follower mutation:

```text
thread-follower-start-turn
thread-follower-steer-turn
thread-follower-interrupt-turn
thread-follower-compact-thread
thread-follower-edit-last-user-turn
thread-follower-set-model-and-reasoning
thread-follower-set-collaboration-mode
thread-follower-set-queued-follow-ups-state
```

Shared owner-routed parameter:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4"
}
```

When the Desktop window is a follower, internal code may call the owner through `targetClientId`.

## Failure Modes For Handrail

Wrong deeplink:

- `codex://local/<conversationId>` resembles the internal renderer route but is not an observed external parser route.
- Handrail should use `codex://threads/<conversationId>`.

No owner window:

- The IPC response can fail with `no-client-found`.
- The owner renderer cannot handle the follower method.

Stale owner:

- The owner client id may refer to a destroyed or unavailable web contents.
- Desktop code can mark the conversation as needing resume when an unavailable owner is detected.

Timeout:

- Follower actions are routed through the renderer and can time out if the owner does not respond.

Follower-only state:

- A follower may know the conversation id but fail the ownership check for mutation.

## Handrail Implication

The deterministic iOS-to-Desktop turn path is:

1. Open `codex://threads/<conversationId>`.
2. Send `thread-follower-start-turn` with the same conversation id.
3. Treat IPC errors as hard failures.

The invariant is:

```text
Conversation mutation belongs to the Desktop owner renderer.
```

