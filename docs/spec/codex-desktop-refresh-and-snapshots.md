# Codex Desktop Refresh And Snapshots

This document records the observed Desktop snapshot and resume paths that may explain how already-rendered conversation views repaint.

Observed Desktop build:

- App version: `26.422.71525`
- Build number: `2210`
- Bundle id: `com.openai.codex`

Related specs:

- [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md)
- [Codex Desktop IPC Protocol](codex-desktop-ipc-protocol.md)
- [Codex Desktop Deeplinks](codex-desktop-deeplinks.md)

## Observed Sources

Observed bundle symbols and paths:

- `.vite/build/main-DjuaMcIZ.js`
  - `thread-stream-snapshot-request`
  - `thread-stream-resume-request`
  - `requestSnapshot`
  - `ensureOwnerAvailable`
- `webview/assets/index-D-3V455n.js`
  - `broadcast-conversation-snapshot`
  - `broadcast-conversation-snapshot-for-host`
  - `thread-stream-snapshot-request`
  - `thread-stream-resume-request`
- `webview/assets/app-server-manager-signals-w7HK0qNP.js`
  - `getConversationSnapshot`
  - `getSnapshotForConversation`

## Observed Internal Paths

Snapshot request:

```text
thread-stream-snapshot-request
```

Snapshot broadcast:

```text
broadcast-conversation-snapshot
broadcast-conversation-snapshot-for-host
```

Resume request:

```text
thread-stream-resume-request
```

Observed main-process behavior:

- Overlay/window state can request a snapshot from the owner web contents.
- The request includes `hostId` and `conversationId`.
- The renderer handles the request by calling `broadcast-conversation-snapshot-for-host`.
- If an owner is destroyed, Desktop can look for another window with the same host id and send `thread-stream-resume-request`.

## Observed Versus Inferred

Observed:

- Desktop has an internal snapshot request path.
- Desktop has an internal snapshot broadcast handler.
- Snapshot and resume messages are routed by `hostId` and `conversationId`.
- These paths are used inside Desktop window and overlay management.

Inferred:

- Snapshot broadcast is a renderer-state repaint or state-sharing mechanism, not a normal app-server turn operation.
- If Handrail can trigger the same mechanism through IPC, it may provide an explicit force-refresh path for a visible Desktop conversation.

Unknown:

- Whether external IPC clients can call `broadcast-conversation-snapshot` directly.
- Whether `ipc-request` can target the right renderer client for this method.
- Whether snapshot broadcast reloads from disk, publishes current memory state, or both.

## Next Deterministic Probe

Goal:

```text
Can an external Handrail IPC client cause the Desktop owner renderer to broadcast or refresh conversation state for a specific conversationId?
```

Probe outline:

1. Open Codex Desktop to `codex://threads/<conversationId>`.
2. Initialize a Handrail IPC client.
3. Send a single `ipc-request` for `broadcast-conversation-snapshot` with `{ conversationId }`.
4. If needed, repeat once with `targetClientId` equal to the observed owner client id from a successful follower response.
5. Record the exact response envelope and whether the visible Desktop chat repaints.

This probe should not silently fall back to another method. A `resultType: "error"` response is a real finding.

## Handrail Implication

The current safe mutation path is still `thread-follower-start-turn`. Snapshot broadcast is a candidate refresh path, not an implemented contract.

The invariant is:

```text
Starting a turn mutates state; snapshot broadcast may only publish existing state.
```

