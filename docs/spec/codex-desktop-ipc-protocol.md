# Codex Desktop IPC Protocol

This document records the Codex Desktop IPC protocol as observed from Handrail, the installed Codex Desktop bundle, and live socket probes on macOS.
For route selection, see [Codex Desktop Deeplinks](codex-desktop-deeplinks.md). For owner/follower behavior, see [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md).

Observed Desktop build:

- App version: `26.422.71525`
- Build number: `2210`
- Bundle id: `com.openai.codex`
- Socket path: `/tmp/codex-ipc/ipc-{uid}.sock`

The protocol is not JSON-RPC. It is a local Desktop routing protocol used by the Electron main process to connect outside clients, Desktop windows, and Desktop-owned app-server clients.

## Transport

The socket is a Unix domain socket on macOS:

```text
/tmp/codex-ipc/ipc-{uid}.sock
```

`{uid}` is the numeric Unix user id. Older or non-POSIX code paths may use `ipc.sock`, but current macOS Desktop builds use the uid-scoped path.

Each message is one binary frame:

```text
uint32_le byte_length
utf8_json_payload
```

`byte_length` is the number of bytes in the UTF-8 JSON payload, not the total frame length. Multiple frames may arrive in one socket read, and one frame may be split across reads.

## Request Envelope

Every client request observed by Handrail uses this shape:

```json
{
  "type": "request",
  "requestId": "client-chosen-request-id",
  "sourceClientId": "server-issued-client-id",
  "version": 0,
  "method": "initialize",
  "params": {}
}
```

Fields:

- `type`: always `"request"` for client requests.
- `requestId`: caller-chosen correlation id.
- `sourceClientId`: `"initializing-client"` before initialization, then the `clientId` returned by `initialize`.
- `version`: protocol family selector. Use `0` for ordinary methods and `1` for `thread-follower-*`.
- `method`: method name.
- `params`: method-specific JSON object.

## Response Envelope

Successful responses have this observed shape:

```json
{
  "type": "response",
  "requestId": "client-chosen-request-id",
  "resultType": "success",
  "method": "initialize",
  "handledByClientId": "server-or-window-client-id",
  "result": {}
}
```

Error responses have this observed shape:

```json
{
  "type": "response",
  "requestId": "client-chosen-request-id",
  "resultType": "error",
  "error": "no-client-found"
}
```

`method` and `handledByClientId` are present on observed success responses but should be treated as diagnostic metadata. The stable routing contract is `requestId`, `resultType`, and either `result` or `error`.

## Initialization

The first request on a connection must initialize the client:

```json
{
  "type": "request",
  "requestId": "init-1",
  "sourceClientId": "initializing-client",
  "version": 0,
  "method": "initialize",
  "params": {
    "clientType": "handrail"
  }
}
```

Observed response:

```json
{
  "type": "response",
  "requestId": "init-1",
  "resultType": "success",
  "method": "initialize",
  "handledByClientId": "af987d95-6feb-4554-bcf4-8dbecc25a19a",
  "result": {
    "clientId": "af987d95-6feb-4554-bcf4-8dbecc25a19a"
  }
}
```

The returned `clientId` must be sent as `sourceClientId` on later requests over that connection. `clientType` is an identity label, not authentication.

## Version Families

Use this deterministic mapping:

```ts
function ipcVersion(method: string): 0 | 1 {
  return method.startsWith("thread-follower-") ? 1 : 0;
}
```

Observed version `1` methods are routed through the live Desktop window that owns the target conversation. The Desktop checks ownership before executing the request.

## Routing Model

The Desktop main process registers IPC clients for Desktop web contents and routes `thread-follower-*` calls through the Desktop owner window for the target conversation.

Ownership details, failure modes, and `targetClientId` behavior are documented in [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md).

The shared required field for follower requests is:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4"
}
```

Common routing failures:

- `no-client-found`: no window client was available to handle the method.
- `thread-follower-*-timeout`: the main process did not receive the renderer response before its timeout.
- `webcontents-destroyed`: the owning Desktop window disappeared while a request was pending.

The Desktop bundle uses a 5 second timeout for renderer-routed follower actions.

## Thread Follower Methods

The installed Desktop build exposes these version `1` methods:

| Method | Params | Result |
|---|---|---|
| `thread-follower-start-turn` | `{ conversationId, turnStartParams }` | `{ result }` |
| `thread-follower-compact-thread` | `{ conversationId }` | `{ ok: true }` |
| `thread-follower-steer-turn` | `{ conversationId, input, restoreMessage?, attachments? }` | `{ result }` |
| `thread-follower-interrupt-turn` | `{ conversationId }` | `{ ok: true }` |
| `thread-follower-set-model-and-reasoning` | `{ conversationId, model, reasoningEffort }` | `{ ok: true }` |
| `thread-follower-set-collaboration-mode` | `{ conversationId, collaborationMode }` | `{ ok: true }` |
| `thread-follower-edit-last-user-turn` | `{ conversationId, turnId, message, agentMode }` | `{ ok: true }` |
| `thread-follower-command-approval-decision` | `{ conversationId, requestId, decision }` | `{ ok: true }` |
| `thread-follower-file-approval-decision` | `{ conversationId, requestId, decision }` | `{ ok: true }` |
| `thread-follower-permissions-request-approval-response` | `{ conversationId, requestId, response }` | `{ ok: true }` |
| `thread-follower-submit-user-input` | `{ conversationId, requestId, response }` | `{ ok: true }` |
| `thread-follower-submit-mcp-server-elicitation-response` | `{ conversationId, requestId, response }` | `{ ok: true }` |
| `thread-follower-set-queued-follow-ups-state` | `{ conversationId, state }` | `{ ok: true }` |

### `thread-follower-start-turn`

Minimum request Handrail already constructs:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4",
  "turnStartParams": {
    "input": [
      {
        "type": "text",
        "text": "Continue from phone",
        "text_elements": []
      }
    ],
    "cwd": "/Users/me/project"
  }
}
```

Renderer behavior:

```text
assertThreadFollowerOwner(conversationId)
start turn with turnStartParams
return { result }
```

This is the right path for Handrail's "send prompt to visible Desktop thread" feature because it preserves Desktop ownership and GUI state.

### `thread-follower-steer-turn`

Observed renderer behavior:

```text
assertThreadFollowerOwner(conversationId)
steer active turn with input, restoreMessage, attachments
return { result }
```

Likely request shape:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4",
  "input": [
    {
      "type": "text",
      "text": "Use the narrower implementation.",
      "text_elements": []
    }
  ],
  "restoreMessage": null,
  "attachments": []
}
```

This is the most direct candidate for a Handrail mid-turn steering feature. It should be added behind a focused integration test against a live Desktop build because `restoreMessage` and `attachments` are passed through to an internal renderer function rather than normalized at the IPC boundary.

### `thread-follower-interrupt-turn`

Request:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4"
}
```

Renderer behavior:

```text
assertThreadFollowerOwner(conversationId)
interrupt conversation
return { ok: true }
```

The Desktop owner may fall back internally to `turn/interrupt` with the current `turnId` when direct follower routing is unavailable.

### Approval And Input Replies

The approval and input reply methods all share this pattern:

```text
assertThreadFollowerOwner(conversationId)
reply to pending requestId with payload
return { ok: true }
```

Observed methods:

- `thread-follower-command-approval-decision`
- `thread-follower-file-approval-decision`
- `thread-follower-permissions-request-approval-response`
- `thread-follower-submit-user-input`
- `thread-follower-submit-mcp-server-elicitation-response`

The `requestId` is the Desktop/app-server request id for the pending approval, user-input, or MCP elicitation item. Handrail can recover candidates from rollout events or structured app-server notifications if it keeps a managed app-server client alive.

### Model, Reasoning, And Collaboration Mode

`thread-follower-set-model-and-reasoning` takes:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4",
  "model": "gpt-5.5",
  "reasoningEffort": "high"
}
```

Renderer behavior:

```text
assertThreadFollowerOwner(conversationId)
set model and reasoning effort for the next turn
return { ok: true }
```

`thread-follower-set-collaboration-mode` takes:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4",
  "collaborationMode": "default"
}
```

The exact valid collaboration mode values come from the app-server `collaborationMode/list` surface, not from the IPC protocol itself.

### Edit Last User Turn

Request:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4",
  "turnId": "turn-id",
  "message": "Replacement user message",
  "agentMode": null
}
```

Renderer behavior:

```text
assertThreadFollowerOwner(conversationId)
find matching turnId in conversation state
edit user turn
return { ok: true }
```

If the turn cannot be found in Desktop state, the renderer throws `Conversation state not found.`

### Queued Follow-Ups

Request:

```json
{
  "conversationId": "019dc424-e857-76e0-8229-589ecf107eb4",
  "state": {
    "019dc424-e857-76e0-8229-589ecf107eb4": []
  }
}
```

Renderer behavior:

```text
assertThreadFollowerOwner(conversationId)
persist queued follow-up state
broadcast thread-queued-followups-changed
return { ok: true }
```

This is a Desktop GUI state mutation, not an app-server turn operation.

## Non-Follower Method: `ipc-request`

The Desktop main process also exposes a version `0` internal request method named `ipc-request` to renderer code. It forwards a method and params to a registered IPC client:

```json
{
  "method": "some-method",
  "params": {},
  "targetClientId": "optional-client-id"
}
```

This is not currently a Handrail feature surface. It is useful to know because it explains the generalized routing layer, but Handrail should prefer explicit `thread-follower-*` methods for Desktop thread control.

## Implementation Contract For Handrail

Handrail should keep the IPC client narrow:

1. Connect to `/tmp/codex-ipc/ipc-{uid}.sock`.
2. Send `initialize` with `sourceClientId: "initializing-client"` and `version: 0`.
3. Store `result.clientId`.
4. For each request, frame exactly one JSON object with a deterministic `requestId`.
5. Use `version: 1` for every `thread-follower-*` method.
6. Treat `resultType: "error"` as a hard failure; do not silently retry through another path.
7. For Desktop thread operations, open/focus `codex://threads/{conversationId}` before follower requests that require a live owner window.

The invariant is:

```text
Desktop IPC is a GUI-owner router, not a general app-server replacement.
```

Use it when the feature depends on the Desktop owner window. Use the Desktop-bundled app-server when the feature is a headless harness operation.

## Feature Candidates

The reverse-engineered methods unlock these concrete Handrail features:

- Mid-turn steering: `thread-follower-steer-turn`
- Structured approvals from iOS: command, file, permissions, user-input, and MCP elicitation response methods
- Per-thread next-turn model/reasoning updates
- Collaboration mode updates
- Compact current Desktop thread
- Edit last user turn
- Queue and manage Desktop follow-up messages

The safest next feature is mid-turn steering because it has the same conversation ownership model as start/interrupt and does not require reconstructing approval request ids.

Approval response features need a reliable request id source before implementation.

## Status

Observed:

- The socket path, binary framing, request envelope, response envelope, initialization flow, and `thread-follower-*` method names were observed from the installed Desktop build and Handrail probes.
- Version `1` is required for `thread-follower-*` methods.
- `ipc-request` exists as a generalized internal forwarding surface.

Inferred:

- Handrail should keep Desktop IPC narrow and prefer explicit `thread-follower-*` methods for GUI-owned thread operations.
- `ipc-request` is useful for targeted probes, but it should not replace follower methods for ordinary Desktop thread control without a successful live test.

Unknown:

- The full set of version `0` internal methods safe for external clients.
- Whether `ipc-request` can be used by Handrail to trigger snapshot refresh behavior.
