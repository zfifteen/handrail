# Handrail Integration Specs

## Active — Grok Build (2026-06 revival)

Handrail on branch `revive/grok-build` supervises **Grok Build** on the Mac. Start here:

| Document | Purpose |
|---|---|
| [REVIVAL.md](../REVIVAL.md) | Migration handoff, phase plan, open decisions |
| [Grok Build Adapter](grok-build-adapter.md) | ACP stdio contract, session paths, approval routing |
| [Handrail WebSocket Protocol](handrail-websocket-protocol.md) | CLI ↔ iOS local WebSocket message contract |
| [Handrail iOS Pairing Persistence](handrail-ios-pairing-persistence.md) | Keychain token + UserDefaults metadata |
| [Handrail Notification Suppression](handrail-notification-suppression.md) | Active-chat notification contract |
| [Handrail Chat UI Contract](handrail-chat-codex-desktop-clone-contract.md) | Mobile chat detail visual/behavior contract (Grok Build is now the source of truth) |

Phase findings:

- [PHASE0_FINDINGS.md](../PHASE0_FINDINGS.md) — spike go/no-go
- [PHASE3_FINDINGS.md](../PHASE3_FINDINGS.md) — E2E WebSocket validation
- [PHASE4_FINDINGS.md](../PHASE4_FINDINGS.md) — polish and refinement

## Legacy — Codex Desktop era

The documents below record Codex Desktop behavior from the pre-revival Handrail (build `26.422.71525`). They are **historical reference only** and do not describe the active Grok Build adapter.

| Document | Purpose |
|---|---|
| [Codex Desktop Deeplinks](codex-desktop-deeplinks.md) | External `codex://` routes |
| [Codex Desktop IPC Protocol](codex-desktop-ipc-protocol.md) | Unix socket framing and follower methods |
| [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md) | Owner/follower state |
| [Codex Desktop Refresh And Snapshots](codex-desktop-refresh-and-snapshots.md) | Internal snapshot paths |
| [Codex Desktop App Server](codex-desktop-app-server.md) | Renderer/app-server boundary |
| [Codex Desktop Persistence](codex-desktop-persistence.md) | SQLite thread metadata and rollout files |

Legacy design artifacts: [docs/design/phase-1-codex-clone-mockups/](../design/phase-1-codex-clone-mockups/)

## Integration chain (Grok Build)

```text
pairing -> WebSocket hello -> chat_list/detail -> ACP prompt -> approval (if needed) -> transcript poll
```

The invariant is:

```text
Grok Build remains the authority for session execution; Handrail supervises through ACP and session files.
```