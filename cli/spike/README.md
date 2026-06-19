# Phase 0 Spikes — Grok Build Adapter

Prove Handrail can talk to Grok Build. Spikes passed; adapter promoted to `cli/src/` on branch `revive/grok-build`.

## Run

```sh
cd /Users/velocityworks/IdeaProjects/handrail/cli
npm install
npm run spike
```

Individual spikes:

| npm script | Purpose |
|------------|---------|
| `spike:list` | List sessions from `~/.grok/sessions/` |
| `spike:transcript` | Parse `updates.jsonl` → Handrail transcript lines |
| `spike:approval` | ACP `session/new` + write-tool turn |
| `spike:resume` | ACP `session/load` + follow-up prompt |

## Environment

- Authenticated Grok CLI (`grok login` or cached `~/.grok/auth.json`)
- `GROK_BIN` — override path to grok binary
- `GROK_HOME` — override `~/.grok`
- `SPIKE_SESSION_ID` — force a specific session for transcript/resume spikes

## Layout

```
spike/
  lib/
    grokPaths.ts      # ~/.grok paths
    grokSessions.ts   # session index from summary.json
    transcript.ts     # updates.jsonl → User/Grok/Tool lines
    acpClient.ts      # minimal ACP stdio client
  01-list-sessions.ts
  02-parse-transcript.ts
  03-acp-approval.ts
  04-resume-session.ts
  run-all.ts
```

Findings and go/no-go: `../../docs/PHASE0_FINDINGS.md`.