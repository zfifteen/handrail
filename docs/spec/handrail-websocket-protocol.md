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
- `cli/src/chats.ts` currently rejects both commands with a visible error.
- Codex Desktop IPC exposes owner-routed approval reply methods that require the Desktop/app-server request id for the pending approval, user input, or MCP elicitation.

Inferred:

- A Handrail `approvalId` must not be invented from transcript text.
- First-class approval routing requires live Desktop/app-server request events that identify the pending request id and approval kind before iOS approval buttons can mutate Desktop state.
- Pattern-detected transcript or status text may support notification copy, but it is not enough evidence to send an approval decision.

Unknown:

- The complete app-server notification envelope for pending approval, input, and MCP elicitation requests.

The invariant is:

```text
Approval actions must route a real Desktop pending request id through the Desktop owner, not a guessed transcript marker.
```
