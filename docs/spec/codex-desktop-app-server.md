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
  - `codexDesktopAppServerTurnStartParams`
  - `createCodexDesktopThread`
  - `startCodexDesktopAppServerTurn`
  - `startCodexDesktopConversation`
- `cli/src/codexSessions.ts`
  - `listCodexChats`
  - `readDesktopThreads`
  - `readRolloutLines`

Observed Desktop bundle symbols:

- `thread/start`
- `turn/start`
- `turn/completed`
- `thread/list`
- `thread/unsubscribe`
- `thread/backgroundTerminals/clean`
- `thread/metadata/update`
- `thread/compact/start`

## Boundary

Observed:

- Handrail can start a new Desktop thread through the Desktop-bundled app-server with `thread/start`.
- Handrail starts the first turn for a new Desktop thread over the same app-server connection with `turn/start`.
- Handrail keeps that app-server child alive until it observes `turn/completed` for the thread.
- Handrail continues existing Desktop-visible threads through Desktop IPC with `thread-follower-start-turn`.
- Desktop renderer code uses `thread/list` to fetch recent conversations.
- Desktop renderer code uses `thread/unsubscribe` when an inactive owner conversation should stop streaming.

Inferred:

- The app-server owns durable thread operations and rollout persistence.
- The renderer owns visible conversation state and owner-routed GUI mutation.
- New chat creation should keep `thread/start` and the first `turn/start` on one app-server connection.
- Creating and starting a thread through the app-server does not by itself prove that Handrail may broadcast a mobile-visible chat; the new `codex:` thread must first appear in Handrail's Desktop-derived chat list.

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

## Handrail `turn/start`

For the first turn in a newly created thread, Handrail sends `turn/start` over the same app-server child process:

```json
{
  "threadId": "019dc424-e857-76e0-8229-589ecf107eb4",
  "input": [
    {
      "type": "text",
      "text": "Start from phone",
      "text_elements": []
    }
  ],
  "cwd": "/Users/me/project"
}
```

Handrail retains the app-server client until it sees:

```json
{
  "method": "turn/completed",
  "params": {
    "threadId": "019dc424-e857-76e0-8229-589ecf107eb4"
  }
}
```

Observed local validation is still blocked when the automation sandbox cannot access `~/.codex/sessions`, but the current unit contract requires `thread/start` followed by `turn/start` for new Desktop conversations.

## Mutation Classes

Appears to mutate persisted or durable thread state:

- `thread/start`
- `turn/start`
- `thread/metadata/update`
- `thread/compact/start`
- `thread/unsubscribe`

Appears to mutate live owner renderer state:

- `thread-follower-start-turn` for continuing an existing Desktop-visible thread
- `thread-follower-steer-turn`
- `thread-follower-interrupt-turn`
- `thread-follower-edit-last-user-turn`
- `thread-follower-set-queued-follow-ups-state`

Appears read-oriented:

- `thread/list`
- Handrail's direct SQLite and rollout reads

## Handrail Implication

The app-server is necessary for creating and reading Desktop thread state. For a new Handrail-created chat, the first prompt belongs on the same app-server connection as `thread/start`; for an existing Desktop-visible chat, Handrail still uses the Desktop IPC owner route.

Handrail must not emit `chat_started`, `chat_event`, or a `chat_list` entry for a new chat until the Desktop-derived read model exposes the new `codex:` id.

The invariant is:

```text
Durable state and visible renderer state are related but not identical integration surfaces.
```
