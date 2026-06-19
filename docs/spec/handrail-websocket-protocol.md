# Handrail WebSocket Protocol

This document records the observable WebSocket contract shared by the Handrail CLI and iOS app.

Related source:

- `cli/src/types.ts`
- `cli/src/server.ts`
- `ios/Handrail/Handrail/Networking/HandrailMessages.swift`
- `ios/Handrail/Handrail/Stores/HandrailStore.swift`

## Boundary

Observed:

- The CLI exposes one local WebSocket server.
- iOS authenticates with `hello` and the pairing token.
- Server messages are JSON objects with a string `type`.
- iOS decodes each supported server `type` explicitly.
- Unknown server `type` values become a visible protocol error instead of being ignored.

Inferred:

- The CLI TypeScript `ServerMessage` union and the iOS `ServerMessage` enum are the same protocol boundary in two languages.
- Adding a server message type requires a matching iOS decoder and store behavior in the same change.

Unknown:

- Whether protocol versioning should move from the pairing payload into every WebSocket message.

## Client Messages

Observed iOS-to-CLI messages:

```text
hello
register_push_token
get_chat_detail
start_chat
continue_chat
send_chat_input
approve
deny
stop_chat
run_automation
pause_automation
delete_automation
```

The first message must be `hello` with the pairing token. Other messages are accepted only after authentication.

## Server Messages

Observed CLI-to-iOS messages:

```text
machine_status
new_chat_options
automation_list
chat_list
chat_detail
chat_started
chat_event
approval_required
command_result
error
```

`command_result` is the success acknowledgement for local commands such as stopping a chat or running, pausing, or deleting a Desktop automation:

```json
{
  "type": "command_result",
  "ok": true,
  "message": "Automation paused."
}
```

iOS records successful command results in Activity. If a future server response uses `ok: false`, iOS reports the message through the same visible error path used for server `error`.

## Unknown Message Contract

An unknown server message is protocol drift.

iOS must surface the unknown type value:

```text
Unsupported server message type: <type>.
```

The invariant is:

```text
Protocol drift must become visible during development instead of being silently dropped.
```

## Approval Routing Boundary

Observed:

- iOS can send `approve` and `deny` with `chatId` and `approvalId`.
- For Handrail-started Grok ACP turns, `cli/src/chats.ts` accepts both commands only when `chatId` plus `approvalId` matches a pending ACP permission request.
- Unknown or stale approval ids are rejected with a visible error.
- `approval_required` is emitted from Grok ACP `session/request_permission` handled in `cli/src/grokBuildAcp.ts`, not from transcript text.
- Approval requests wait until the corresponding `grok:` session appears in Handrail's chat list before the CLI emits mobile-visible approval state.
- When the CLI records a pending approval, it also emits a refreshed `chat_list` with the matching chat overlaid as `waiting_for_approval`.
- Approve/deny routes the selected ACP permission option back to the deferred Grok ACP response.

Inferred:

- A Handrail `approvalId` must not be invented from transcript text.
- First-class approval routing requires ACP permission events that identify the tool call id and approval kind before iOS approval buttons can mutate Grok state.
- Pattern-detected transcript or status text may support notification copy, but it is not enough evidence to send an approval decision.

Unknown:

- Whether workspace writes under `sandbox=workspace` always surface `session/request_permission` to iOS.
- The complete envelope for all Grok tool kinds that may request permission.

The invariant is:

```text
Approval actions must route a real Desktop pending request id through the Desktop owner, not a guessed transcript marker.
```

The route key in the mobile protocol is the pair:

```text
chatId + approvalId
```

The `approvalId` remains the raw app-server request id. Handrail must not treat that id as globally unique across independent app-server child processes.

The related no-orphan invariant is:

```text
App-server approval events may surface in iOS only after the same thread exists in the Desktop-derived Handrail chat list.
```
