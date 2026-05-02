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
- `item/commandExecution/requestApproval`
- `item/fileChange/requestApproval`
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
- For Handrail-started app-server turns, Handrail can receive `item/commandExecution/requestApproval` and `item/fileChange/requestApproval` requests from the app-server and respond on the same request id.
- For Handrail-started app-server turns, Handrail ingests observed live app-server notifications and rebroadcasts thread-scoped state through the normal mobile `chat_event` and `chat_list` path.
- Handrail continues existing Desktop-visible threads through Desktop IPC with `thread-follower-start-turn`.
- Desktop renderer code uses `thread/list` to fetch recent conversations.
- Desktop renderer code uses `thread/unsubscribe` when an inactive owner conversation should stop streaming.

Inferred:

- The app-server owns durable thread operations and rollout persistence.
- The renderer owns visible conversation state and owner-routed GUI mutation.
- New chat creation should keep `thread/start` and the first `turn/start` on one app-server connection.
- Creating and starting a thread through the app-server does not by itself prove that Handrail may broadcast a mobile-visible chat; the new `codex:` thread must first appear in Handrail's Desktop-derived chat list.

Unknown:

- The complete notification stream emitted by the app-server.
- Whether there is an app-server method that forces a renderer to reload one conversation from persistence.
- Whether existing Desktop-owned turns can be attached to a durable app-server approval request stream without starting the turn through Handrail's app-server child.

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

## Handrail Approval Requests

For turns started through `turn/start`, Codex Desktop app-server sends approval requests as newline-delimited JSON objects with `id`, `method`, and `params`. The app-server request `id` is the only response correlation key Handrail can safely expose as a mobile `approvalId`.

Command approval request:

```json
{
  "id": "server-request-1",
  "method": "item/commandExecution/requestApproval",
  "params": {
    "threadId": "019dc424-e857-76e0-8229-589ecf107eb4",
    "turnId": "turn-1",
    "itemId": "item-1",
    "approvalId": null,
    "command": "npm test",
    "reason": null
  }
}
```

File-change approval request:

```json
{
  "id": "server-request-2",
  "method": "item/fileChange/requestApproval",
  "params": {
    "threadId": "019dc424-e857-76e0-8229-589ecf107eb4",
    "turnId": "turn-1",
    "itemId": "item-2",
    "grantRoot": "/Users/me/project",
    "reason": "Codex requests write access."
  }
}
```

Handrail maps each request into:

```json
{
  "type": "approval_required",
  "chatId": "codex:019dc424-e857-76e0-8229-589ecf107eb4",
  "approvalId": "server-request-1",
  "title": "Command approval required",
  "summary": "npm test",
  "files": [],
  "diff": ""
}
```

When iOS approves or denies the request, Handrail responds to the same app-server child:

```json
{
  "id": "server-request-1",
  "result": {
    "decision": "accept"
  }
}
```

Denial uses:

```json
{
  "id": "server-request-1",
  "result": {
    "decision": "decline"
  }
}
```

The invariant is:

```text
A Handrail approvalId is the app-server request id, not transcript text, a local UUID, or an inferred item id.
```

## Handrail Request IDs

Observed:

- Handrail sends app-server requests as newline-delimited JSON objects with `id`, `method`, and `params`.
- Handrail uses the fixed id `__codex_initialize__` for `initialize`.
- Handrail uses a per-client deterministic counter for later request ids:

```text
thread/start:1
turn/start:2
```

Inferred:

- The app-server treats `id` as a request/response correlation key.
- Request ids do not need randomness when one Handrail app-server client sends one ordered request stream.

The invariant is:

```text
App-server request correlation must be auditable from the emitted request stream.
```

## Handrail Live Notifications

Handrail maps only observed thread-scoped app-server notifications into mobile protocol events:

| App-server notification | Handrail event |
| --- | --- |
| `turn/started` | `chat_event` kind `turn_started`, status `running` |
| `turn/completed` with turn status `completed` | `chat_event` kind `chat_completed`, status `completed` |
| `turn/completed` with turn status `failed` | `chat_event` kind `chat_failed`, status `failed` |
| `turn/completed` with turn status `interrupted` | `chat_event` kind `chat_stopped`, status `stopped` |
| `item/agentMessage/delta` | `chat_event` kind `output` |

When a mapped live event carries a status, Handrail overlays that status on the Desktop-derived `codex:` chat row and broadcasts a refreshed `chat_list`. This keeps Codex Desktop visibility as the gate: live events can update a visible Desktop chat, but they do not create mobile-only chats.

The invariant is:

```text
Live app-server events may enrich a Desktop-visible Handrail row; they must not create an independent Handrail chat source.
```

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
