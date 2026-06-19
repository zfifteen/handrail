# Grok Build Adapter

Handrail controls Grok Build through the official Grok CLI's ACP stdio protocol. This is the active integration contract after the Codex Desktop revival migration.

Canonical handoff: [REVIVAL.md](../REVIVAL.md)

## Architecture

```text
iOS Handrail  --WebSocket-->  handrail CLI  --ACP stdio-->  grok agent
                                    |
                                    +-- reads ~/.grok/sessions/**/summary.json
                                    +-- reads updates.jsonl for transcripts
                                    +-- watches active_sessions.json for live status
```

## Chat identity

- Chat IDs use the `grok:<session-id>` prefix.
- Session files live under `~/.grok/sessions/<encoded-cwd>/<session-id>/`.
- Live PIDs are tracked in `~/.grok/active_sessions.json`.

## ACP spawn contract

Handrail-owned children use:

```text
grok --sandbox workspace --tools read_file,grep,list_dir,write,run_terminal_cmd \
  -m <model> --effort <level> agent --no-leader stdio
```

`--no-leader` is required for Handrail-owned ACP children. Attach with `--leader` only when the session PID exists in `active_sessions.json`.

## Required ACP handlers

The CLI must respond to incoming ACP requests or `session/prompt` blocks indefinitely:

| Method | Handler |
|--------|---------|
| `session/request_permission` | Defer to iOS; respond after approve/deny |
| `fs/read_text_file` | Read from local filesystem |
| `fs/write_text_file` | Write to local filesystem |
| `terminal/create` | Spawn command locally |
| `terminal/output` | Return captured stdout/stderr |
| `terminal/wait_for_exit` | Wait for process exit |
| `terminal/kill` | Terminate process |
| `terminal/release` | Release terminal resources |

Implementation: `cli/src/grokBuildAcp.ts`

## Session listing and transcripts

- Session index: `cli/src/grokSessions.ts`
- Transcript parser (`User:` / `Grok:` / `Tool:`): `cli/src/grokTranscript.ts`
- New chat options (projects, models, defaults): `cli/src/grokNewChatOptions.ts` or `newChatOptions.ts` Grok path

## Approvals

- ACP `session/request_permission` maps to Handrail `approval_required` WebSocket messages.
- `approvalId` is the Grok tool call id from the ACP request.
- Approve/deny routes through `cli/src/chats.ts` back to the deferred ACP response.

## v1 limitations

- Grok automations: empty list; run/pause/delete throw.
- No dedicated `updates.jsonl` file watcher (5s poll via server observer).
- Workspace writes under `sandbox=workspace` may auto-approve without surfacing iOS approval UI.

## Validation

```sh
cd cli && npm test && npm run spike
node tools/qa/grok_e2e_probe.mjs   # requires handrail serve
```

Evidence: [PHASE3_FINDINGS.md](../PHASE3_FINDINGS.md), [PHASE4_FINDINGS.md](../PHASE4_FINDINGS.md)