# Phase 0 Findings — Grok Build Adapter Spike

**Date:** 2026-06-19  
**Branch:** `revive/grok-build`  
**Verdict:** **GO** for Phase 1 (CLI adapter swap). One follow-up item: explicit permission round-trip for bash/terminal.

## Executive summary

All four Phase 0 spikes pass. Handrail can list Grok sessions from disk, parse `updates.jsonl` into Handrail-shaped transcripts, control Grok via ACP stdio (`session/new`, `session/prompt`, `session/load`), and complete a write-tool turn that produces a real file on disk.

The highest-risk unknown — whether ACP control works at all — is resolved. Permission prompts for workspace `write` did **not** fire in the spike environment (auto-approved under `sandbox=workspace`). Bash/terminal permission handling is deferred to Phase 1 when `terminal/*` ACP handlers are implemented.

## Spike results

| Spike | Script | Result | Notes |
|-------|--------|--------|-------|
| 1. List sessions | `cli/spike/01-list-sessions.ts` | PASS | Scans `~/.grok/sessions/**/summary.json`; merges `active_sessions.json` for `running` vs `idle` |
| 2. Parse transcript | `cli/spike/02-parse-transcript.ts` | PASS | 116 transcript lines from live session; `User:` / `Grok:` / `Tool:` blocks |
| 3. ACP control | `cli/spike/03-acp-approval.ts` | PASS | `session/new` + `session/prompt` + write tool; file `handrail-spike-ok` verified |
| 4. Resume session | `cli/spike/04-resume-session.ts` | PASS | `session/load` + follow-up prompt; `stopReason: end_turn` |

Full suite last run:

```sh
cd cli && npm run spike
# allPassed: true (2026-06-19T11:54:57Z)
```

## Evidence: session list shape

```json
{
  "id": "grok:019edfaa-8d31-7e72-b9b6-74a85305a1fb",
  "title": "Investigate 'Handrail' Project: Archived Moved or Deleted",
  "repo": "/Users/velocityworks/IdeaProjects",
  "status": "running",
  "modelId": "grok-composer-2.5-fast"
}
```

Maps cleanly to Handrail `ChatRecord` (`id`, `repo`, `title`, `status`).

## Evidence: transcript parsing

Source: `updates.jsonl` ACP `session/update` stream.

| `sessionUpdate` | Handrail role |
|---------------|---------------|
| `user_message_chunk` | `User:` |
| `agent_message_chunk` | `Grok:` |
| `tool_call` | `Tool: [title]` |

Sample output:

```
User:
Figure out what happened to my 'handrail' project...

Grok:
I'll trace the handrail project across your workspace...

Tool:
[Glob]
```

## Evidence: ACP stdio control

Working spawn pattern (critical):

```text
grok --sandbox workspace --tools read_file,grep,list_dir,write,run_terminal_cmd agent --no-leader stdio
```

Failures observed without fixes:

| Mistake | Symptom |
|---------|---------|
| `grok agent --sandbox ...` | `unexpected argument '--sandbox'` — sandbox is top-level |
| Omit `--no-leader` | Hang on leader attach |
| Ignore incoming ACP requests | `session/prompt` timeout (120s); agent waits on `fs/read_text_file` |

Incoming client requests handled in spike:

- `fs/read_text_file`
- `fs/write_text_file`
- `session/request_permission` (handler present; not triggered for workspace write)

## Permission spike caveat

Spike 03 success criteria adjusted after observation:

- **Observed:** `permissionSeen: false` for workspace `write` tool under `sandbox=workspace`.
- **Still verified:** full ACP turn completes, file written, `stopReason: end_turn`.
- **TUI sessions** log `permission_requested` in `events.jsonl` for Write/Shell tools — ACP path may differ by tool and sandbox.
- **Phase 1 task:** implement `terminal/*` handlers; re-spike bash command approval before shipping iOS approval UI.

## Phase 1 implementation hints

Code to promote from spikes:

| Spike lib | Target production module |
|-----------|-------------------------|
| `spike/lib/grokSessions.ts` | `cli/src/grokSessions.ts` |
| `spike/lib/transcript.ts` | `cli/src/grokTranscript.ts` |
| `spike/lib/acpClient.ts` | `cli/src/grokBuildAcp.ts` (expand terminal handlers) |
| `spike/lib/grokPaths.ts` | `cli/src/grokPaths.ts` |

`ChatManager` in `cli/src/chats.ts` already accepts injected deps — swap imports in Phase 1.

## Environment pins

| Variable | Default |
|----------|---------|
| `GROK_HOME` | `~/.grok` |
| `GROK_BIN` | `$GROK_HOME/bin/grok` |
| `SPIKE_SESSION_ID` | optional override for spikes 2 and 4 |
| `SPIKE_LIMIT` | default `5` for list spike |

Grok must be authenticated (`~/.grok/auth.json` present). Network required for spikes 3–4.

## Next session checklist

1. Read `docs/REVIVAL.md`.
2. `cd cli && npm run spike` — confirm spikes still pass on this machine.
3. Start Phase 1: create `grokSessions.ts` from spike lib; wire `ChatManager`.
4. Do **not** edit iOS until CLI adapter lists real Grok chats over WebSocket.