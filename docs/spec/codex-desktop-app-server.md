# Codex Desktop App Server

This document records the app-server boundary relevant to Handrail's Desktop integration.

Observed Desktop build:

- App version: `26.422.71525`
- Build number: `2210`
- Bundle id: `com.openai.codex`

Related specs:

- [Codex Desktop IPC Protocol](codex-desktop-ipc-protocol.md)
- [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md)
- [Codex Desktop Persistence](codex-desktop-persistence.md)

## Observed Sources

Observed Handrail source:

- `cli/src/codexDesktopIpc.ts`
  - `CodexDesktopAppServerClient`
  - `codexDesktopThreadStartParams`
  - `createCodexDesktopThread`
  - `startCodexDesktopConversation`
- `cli/src/codexSessions.ts`
  - `listCodexChats`
  - `readDesktopThreads`
  - `readRolloutLines`

Observed Desktop bundle symbols:

- `thread/start`
- `thread/list`
- `thread/unsubscribe`
- `thread/backgroundTerminals/clean`
- `thread/metadata/update`
- `thread/compact/start`

## Boundary

Observed:

- Handrail can start a new Desktop thread through the Desktop-bundled app-server with `thread/start`.
- Handrail then starts the visible turn through Desktop IPC with `thread-follower-start-turn`.
- Desktop renderer code uses `thread/list` to fetch recent conversations.
- Desktop renderer code uses `thread/unsubscribe` when an inactive owner conversation should stop streaming.

Inferred:

- The app-server owns durable thread operations and rollout persistence.
- The renderer owns visible conversation state and owner-routed GUI mutation.
- Creating a thread through the app-server does not by itself prove that an already-open Desktop view has repainted.

Unknown:

- The full app-server request envelope used by Desktop internally.
- The complete notification stream emitted by the app-server.
- Whether there is an app-server method that forces a renderer to reload one conversation from persistence.

## Handrail `thread/start`

Handrail sends:

```json
{
  "model": "gpt-5.5",
  "modelProvider": null,
  "cwd": "/Users/me/project",
  "approvalPolicy": "never",
  "sandbox": "danger-full-access",
  "config": {
    "model_reasoning_effort": "medium"
  },
  "personality": null,
  "ephemeral": false,
  "experimentalRawEvents": false,
  "dynamicTools": null,
  "persistExtendedHistory": false,
  "serviceTier": null
}
```

The expected result contains:

```json
{
  "thread": {
    "id": "019dc424-e857-76e0-8229-589ecf107eb4"
  }
}
```

Handrail treats a missing thread id as a hard failure.

## Mutation Classes

Appears to mutate persisted or durable thread state:

- `thread/start`
- `thread/metadata/update`
- `thread/compact/start`
- `thread/unsubscribe`

Appears to mutate live owner renderer state:

- `thread-follower-start-turn`
- `thread-follower-steer-turn`
- `thread-follower-interrupt-turn`
- `thread-follower-edit-last-user-turn`
- `thread-follower-set-queued-follow-ups-state`

Appears read-oriented:

- `thread/list`
- Handrail's direct SQLite and rollout reads

## Handrail Implication

The app-server is necessary for creating and reading Desktop thread state. It is not sufficient for Desktop-visible sync unless the owner renderer also receives the mutation or a refresh signal.

The invariant is:

```text
Durable state and visible renderer state are related but not identical integration surfaces.
```

