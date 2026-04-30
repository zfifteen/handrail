# Codex Desktop Deeplinks

This document records the Codex Desktop deeplink routes observed in the installed macOS app bundle.
It should be read with [Codex Desktop IPC Protocol](codex-desktop-ipc-protocol.md) and [Codex Desktop Conversation Ownership](codex-desktop-conversation-ownership.md).

Observed Desktop build context:

- URL scheme: `codex`
- External parser source: `/Applications/Codex.app/Contents/Resources/app.asar`
- Renderer route source: bundled webview assets inside the same app bundle

## External URL Scheme

Codex Desktop registers the URL scheme:

```text
codex://
```

The bundle parser recognizes the URL host first. Unsupported hosts are rejected by the parser.

## External Routes

These routes are accepted by the observed external deeplink parser:

| Deeplink | Parsed route |
|---|---|
| `codex://automations` | Automations view |
| `codex://settings` | Settings view |
| `codex://skills` | Skills view |
| `codex://new?prompt=<text>&path=<absolute-path>&originUrl=<git-url>` | New local thread with optional prefilled prompt, cwd, and origin URL |
| `codex://threads/new?prompt=<text>&path=<absolute-path>&originUrl=<git-url>` | New local thread with optional prefilled prompt, cwd, and origin URL |
| `codex://threads/<uuid>` | Existing local conversation |
| `codex://connector/oauth_callback?returnTo=<url>` | Connector OAuth callback |
| `codex://codex-app/apply-config` | Apply Codex app config |

For `codex://new` and `codex://threads/new`, at least one of `prompt`, `path`, or `originUrl` must be present. If all three query parameters are absent, the parser does not return the prefilled new-thread route.

For `codex://threads/<uuid>`, the first path segment after `threads` must parse as a UUID.

## Internal Renderer Routes

The Desktop renderer also contains internal routes that are not identical to the public deeplink surface:

| Internal route | Meaning |
|---|---|
| `/local` | Local threads view |
| `/local/:conversationId` | Existing local conversation |
| `/remote` | Remote tasks view |
| `/remote/:taskId` | Existing remote task |
| `/settings` | Settings view |
| `/skills` | Skills view |
| `/automations` | Automations view |
| `/hotkey-window` | Hotkey window root |
| `/hotkey-window/new-thread` | Hotkey new-thread view |
| `/hotkey-window/thread` | Hotkey thread view |
| `/hotkey-window/thread/:conversationId` | Hotkey existing-thread view |
| `/hotkey-window/remote` | Hotkey remote-task view |
| `/hotkey-window/remote/:taskId` | Hotkey existing-remote-task view |
| `/hotkey-window/worktree-init-v2` | Hotkey worktree initialization |
| `/worktree-init-v2` | Worktree initialization |
| `/global-dictation` | Global dictation |

The internal route `/local/:conversationId` is reached from the external route `codex://threads/<uuid>`.

## Handrail Contract

Handrail should use this external deeplink for opening an existing Desktop conversation:

```text
codex://threads/<conversationId>
```

The previously assumed route:

```text
codex://local/<conversationId>
```

was not found in the external parser. It resembles the internal renderer route, but it is not an observed public deeplink accepted by the macOS URL parser.

## Refresh Implication

The deeplink can ask Codex Desktop to focus an existing conversation. It is not, by itself, a documented force-refresh operation.

For Handrail's iOS-to-Desktop update path, the deterministic route is:

1. Open `codex://threads/<conversationId>`.
2. Send the Desktop IPC `thread-follower-start-turn` request for that same conversation.
3. Treat any IPC routing error as a hard failure.

The invariant is:

```text
The external deeplink chooses the Desktop conversation; the IPC follower request mutates the Desktop-owned conversation.
```

## Status

Observed:

- `codex://threads/<uuid>` is accepted by the external parser and maps to an existing local conversation.
- The internal renderer route for that conversation is `/local/:conversationId`.

Inferred:

- Handrail should use the external route before sending Desktop follower IPC so the intended Desktop window can become the conversation owner.

Unknown:

- Whether opening the same deeplink for an already visible conversation forces React state to reload. No observed parser route names an explicit refresh operation.
