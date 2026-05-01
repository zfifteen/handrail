# Reverse-Engineered Codex Desktop Specs

This folder records Codex Desktop behavior observed for Handrail integration work.

Baseline Desktop build:

- App version: `26.422.71525`
- Build number: `2210`
- Bundle id: `com.openai.codex`
- Bundle path: `/Applications/Codex.app`

These documents are not upstream API documentation. They record observed behavior from a specific installed Desktop build and may drift when Codex Desktop updates.

Handrail treats these specs as living contracts. When Handrail code changes a documented protocol surface or persistence assumption, update the corresponding spec in the same change-set (or file a concrete issue describing the drift).

## Specs

| Document | Purpose | Confidence |
|---|---|---|
| [Codex Desktop Deeplinks](codex-desktop-deeplinks.md) | External `codex://` routes and internal renderer routes. | High for the observed build. |
| [Codex Desktop IPC Protocol](codex-desktop-ipc-protocol.md) | Unix socket framing, request envelopes, follower methods, and Handrail IPC contract. | High for observed request/response framing and exposed method names. |
| [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md) | Owner/follower state, `targetClientId`, renderer ownership checks, and sync failure modes. | Medium-high; based on bundle code and Handrail probes. |
| [Codex Desktop Refresh And Snapshots](codex-desktop-refresh-and-snapshots.md) | Internal snapshot and resume paths that may explain visible Desktop refresh behavior. | Medium; observed paths are concrete, external usability is unknown. |
| [Codex Desktop App Server](codex-desktop-app-server.md) | Renderer/app-server boundary and which operations appear to mutate persisted versus live state. | Medium; Handrail uses a narrow subset. |
| [Codex Desktop Persistence](codex-desktop-persistence.md) | SQLite thread metadata, rollout files, pinned state, and Handrail's read model. | High for Handrail's current reader. |
| [Handrail WebSocket Protocol](handrail-websocket-protocol.md) | CLI-to-iOS and iOS-to-CLI local WebSocket message contract. | High for Handrail-owned source. |
| [Handrail Notification Suppression](handrail-notification-suppression.md) | Current push/local notification flow and the expected active-chat suppression contract. | High for Handrail code paths; Desktop notification internals are out of scope. |

## Integration Chain

The Handrail sync problem should be studied in this order:

```text
selection -> ownership -> mutation -> snapshot/refresh -> persistence -> notifications
```

The invariant is:

```text
Visible Desktop sync depends on Desktop-owned renderer state, not only on persisted rollout state.
```

## Status Vocabulary

Observed:

- Behavior found in the installed app bundle, Handrail source, live socket probes, or local Desktop state files.

Inferred:

- The narrow interpretation Handrail should use when integrating with the observed behavior.

Unknown:

- A boundary that still needs a deterministic probe before it can be treated as a contract.
