# Handrail Revival — Grok Build Migration

**Status:** Phase 4 complete (2026-06-19). Polish shipped; physical iOS install still blocked on host tunnel.

This document is the session handoff for reviving Handrail as a **local-first iPhone/iPad supervisor for Grok Build** on the user's Mac. Read this first in any new agent session before editing code.

## Product thesis (updated)

- **Grok Build** on the Mac is the authority for sessions and execution.
- **Handrail CLI** exposes Grok session state over the existing Handrail WebSocket protocol (port 8787).
- **Handrail iOS** supervises: list chats, view transcripts, continue prompts, approve tools, stop turns.
- **No cloud relay**, no generic SSH terminal, no multi-agent control plane.

Handrail is **not** affiliated with xAI. It is a companion to the official Grok Build CLI.

## Repository state

| Item | Location |
|------|----------|
| Active repo | `/Users/velocityworks/IdeaProjects/handrail` |
| Branch | `revive/grok-build` |
| Git restored from | `IdeaProjects/archive/.git-backups/handrail-20260528.git` |
| Archived copy (read-only reference) | `IdeaProjects/archive/handrail/` |
| Prior sunset reason | Codex Mobile superseded Codex Desktop companion need (2026-05-14) |
| New rationale | No official xAI mobile companion for Grok Build; Handrail fills that gap |

## Architecture (target)

```
iOS Handrail  --WebSocket:8787-->  handrail CLI  --ACP stdio-->  grok agent
                                        |
                                        +-- reads ~/.grok/sessions/**/summary.json
                                        +-- reads updates.jsonl for transcripts
                                        +-- watches active_sessions.json for live status
```

**Adapter swap (Phase 1):** replace Codex modules with Grok modules behind the same `ChatManager` dependency injection.

| Remove | Add |
|--------|-----|
| `cli/src/codexSessions.ts` | `cli/src/grokSessions.ts` |
| `cli/src/codexDesktopIpc.ts` | `cli/src/grokBuildAcp.ts` |
| `cli/src/newChatOptions.ts` (Codex paths) | `cli/src/grokNewChatOptions.ts` |
| `cli/src/automations.ts` (Codex cron) | stub / remove for v1 |

Chat IDs: `codex:<uuid>` → `grok:<session-id>`.

## Phase plan

### Phase 0 — Spike (DONE)

Prove Grok adapter feasibility before touching iOS.

- [x] Restore repo + `revive/grok-build` branch
- [x] Spike scripts in `cli/spike/`
- [x] All four spikes pass (`npm run spike` in `cli/`)

See [PHASE0_FINDINGS.md](./PHASE0_FINDINGS.md) for evidence and caveats.

### Phase 1 — CLI adapter swap (DONE)

- [x] Promoted spike libs into `cli/src/` (`grokSessions`, `grokBuildAcp`, `grokTranscript`, `grokPaths`).
- [x] Wired `ChatManager` deps to Grok adapters; chat IDs use `grok:<session-id>`.
- [x] ACP client handles `fs/*` and `session/request_permission` (deferred response until user approves).
- [x] Server polls `active_sessions.json` every 5s via existing notification observer.
- [x] Tests ported: `cli/test/grokSessions.test.ts` + `cli/test/fixtures/grok/sample-updates.jsonl`.
- [x] `grok --no-leader stdio` for new sessions; `--leader` attach when PID exists in `active_sessions.json`.
- [x] `terminal/*` ACP handlers (create/output/wait/kill/release).
- [ ] **Deferred:** dedicated file watcher on `updates.jsonl` (5s poll sufficient for v1).

**Phase 1 acceptance:** `handrail serve` + WebSocket client can list Grok sessions, load detail, start/continue a session.

### Phase 2 — iOS rebrand + parser (DONE)

- [x] Replaced Codex strings with Grok Build across iOS Swift sources and tests.
- [x] `ChatTranscriptParser`: primary `Grok:` labels; legacy `Codex:` still parsed.
- [x] `CodexChat` model renamed to `GrokChat`; chat IDs use `grok:` prefix in tests/fixtures.
- [x] New chat preview/options use `grok-build` default model (server already sources `grok models`).
- [x] WebSocket protocol v1 unchanged.
- [ ] **Blocked on host:** simulator/device `xcodebuild` (iOS 26.5 SDK / CoreSimulator mismatch on Mac).

### Phase 3 — End-to-end validation (DONE)

- [x] CLI tests 57/57; spikes 4/4.
- [x] Live WebSocket E2E probe (`tools/qa/grok_e2e_probe.mjs`) — handshake, list, detail, continue, start, stop.
- [x] Evidence: [PHASE3_FINDINGS.md](./PHASE3_FINDINGS.md), `docs/artifacts/phase3-grok-e2e-2026-06-19.json`.
- [ ] **Blocked:** physical iPhone/iPad install (`tunnelState is unavailable` via devicectl).
- [ ] **Blocked:** simulator build (iOS 26.5 SDK / CoreSimulator mismatch).
- [ ] Manual iOS smoke per `TEST_PLAN.md` after device install succeeds.

### Phase 4 — Polish (DONE)

- [x] README + privacy policy rebranded for Grok Build.
- [x] New Chat defaults use `grok-build`; automations shortcut hidden when list empty.
- [x] Approval UI polish (title, kind badge, chat context).
- [x] `terminal/*` ACP handlers for bash/command execution.
- [x] APNs configuration errors filtered from user-facing error feed.
- [x] Evidence: [PHASE4_FINDINGS.md](./PHASE4_FINDINGS.md).
- [ ] **Deferred:** App Store screenshots/copy refresh in `store-assets/`.
- [ ] **Deferred:** subagent visibility in transcript UI.
- [ ] **Blocked:** physical device install and simulator build (same as Phase 3).

## Open decisions (need owner input)

1. **Repo name:** keep `handrail` or rename?
2. **GitHub:** recreate `zfifteen/handrail`?
3. **Leader policy:** always attach to running Grok TUI vs always spawn Handrail-owned ACP children?
4. **v1 scope:** drop iPad/automations for faster MVP?

## Key technical notes (from Phase 0)

- Grok CLI spawn for ACP: top-level flags before `agent`, e.g. `grok --sandbox workspace --tools write agent --no-leader stdio`.
- **`--no-leader` is required** for Handrail-owned ACP children; default leader attach can hang.
- ACP client **must** respond to incoming requests (`fs/read_text_file`, `fs/write_text_file`, `session/request_permission`, eventually `terminal/*`). Unanswered requests block `session/prompt` indefinitely.
- Workspace `write` in sandbox may **auto-approve** without `session/request_permission`; bash/terminal paths still need validation in Phase 1.
- Session files: `~/.grok/sessions/<encoded-cwd>/<session-id>/summary.json` + `updates.jsonl`.
- Live PIDs: `~/.grok/active_sessions.json`.
- Grok version observed during spikes: `0.2.56` (agent stdio); pin and re-run spikes after upgrades.

## Commands

```sh
cd /Users/velocityworks/IdeaProjects/handrail/cli
npm install
npm run spike          # all Phase 0 spikes
npm run spike:list
npm run spike:transcript
npm run spike:approval
npm run spike:resume
npm test               # Grok adapter tests + legacy Codex module tests
node tools/qa/grok_e2e_probe.mjs   # Phase 3 live WebSocket validation (server must be running)
```

## References

- Grok CLI study: `IdeaProjects/research/grok-build-cli-control-surface/`
- Grok sessions doc: `~/.grok/docs/user-guide/17-sessions.md`
- Grok ACP doc: `~/.grok/docs/user-guide/15-agent-mode.md`
- Handrail protocol: `docs/spec/handrail-websocket-protocol.md`
- Prior sunset: `archive/handrail/SUNSET.md`