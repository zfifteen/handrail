# Handrail

Handrail is a free, local-first iOS remote control for Codex chats on your own Mac.

It has two parts:

- `handrail`, a desktop CLI that starts a local WebSocket server and exposes Codex chat state to iOS.
- `Handrail`, a SwiftUI iOS app that pairs with the CLI, shows Codex chats, continues chats through the Mac, surfaces approvals, and requests stops.

Works with OpenAI Codex CLI. Not affiliated with OpenAI.

## What Handrail Is Not

Handrail is not a cloud coding workspace, a generic SSH terminal, an account system, a paid product, or a multi-agent control plane. It does not support Claude, Gemini, OpenCode, or other agents. It does not edit files directly. Codex runs locally and Handrail supervises it.

## CLI Install

```sh
cd cli
npm install
npm run build
npm link
```

The CLI prefers the Codex binary bundled in `/Applications/Codex.app/Contents/Resources/codex` when the desktop app is installed, because that binary is updated with the desktop app. If the app bundle is unavailable, Handrail falls back to `codex` on `PATH`.

To use a different local command path for Codex, set:

```sh
export HANDRAIL_AGENT_COMMAND="/path/to/codex exec --json --color never"
```

## Run the Server and Pair

On your Mac:

```sh
handrail pair
```

The command creates or reuses a pairing token in `~/.handrail/state.json`, prints a QR code, and starts the local WebSocket server on port `8787` if it is not already running.

On iOS, open Handrail, tap the QR scanner, and scan the code. The QR payload is JSON containing the protocol version, local host, port, pairing token, and machine name.

## Work With Chats

With `handrail pair` or `handrail serve` running:

```sh
handrail chats
```

The iOS app reads the same Codex Desktop chat list the Mac app uses. It does not create a separate Handrail-owned chat list.

Other CLI commands:

```sh
handrail serve
handrail chats
handrail stop <chat-id>
handrail unpair
```

## Run the iOS App

Open:

```sh
ios/Handrail/Handrail.xcodeproj
```

Select the `Handrail` scheme and run on an iPhone simulator or device. QR scanning requires a camera, so pairing by scan is intended for a physical device.

## Security Model

Handrail is local-first:

- Pairing token required.
- No cloud relay.
- No account.
- No payment code.
- Code stays on the user’s machine.
- CLI executes Codex locally.
- iOS receives chat output, changed file names, and git diffs.
- Local network access is required for the MVP.

The token is stored in `~/.handrail/state.json` on the Mac and in Keychain on iOS. iOS stores only non-secret paired-machine metadata in UserDefaults.

## Approval Behavior

The CLI watches Codex output for simple approval-like text such as `approve`, `permission`, `Do you want to proceed`, or `y/n`. When detected, it emits an `approval_required` event and runs:

```sh
git -C <repo> diff --stat
git -C <repo> diff
git -C <repo> diff --name-only
```

The iOS app shows the summary, changed files, and diff. Approval routing must go through the Codex chat route exposed by the Mac.

## Limitations

- Approval detection is intentionally small pattern matching.
- The WebSocket server is plain local-network `ws://`.
- The iOS app stores the pairing token in Keychain and paired-machine metadata in UserDefaults.
- Handrail does not maintain an independent chat store.
- There is no background daemon, cloud relay, account sync, or generic terminal.

## Tests

```sh
cd cli
npm test
```
