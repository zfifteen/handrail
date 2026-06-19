# Handrail

## Revival (2026-06-19)

Handrail is being revived on branch `revive/grok-build` as a **Grok Build** companion (replacing Codex Desktop). Phases 0–4 complete. **Start here:** [docs/REVIVAL.md](docs/REVIVAL.md) and [docs/PHASE4_FINDINGS.md](docs/PHASE4_FINDINGS.md).

---

Handrail is a free, local-first iOS remote control for Grok Build sessions on your own Mac.

It has two parts:

- `handrail`, a desktop command that starts a local WebSocket server and exposes Grok Build session state to iOS.
- `Handrail`, a SwiftUI iOS app that pairs with the CLI, shows Grok chats, continues sessions through the Mac, surfaces tool approvals, and requests stops.

Works with the official Grok Build CLI. Not affiliated with xAI.

## What Handrail Is Not

Handrail is not a cloud coding workspace, a generic SSH terminal, an account system, a paid product, or a multi-agent control plane. It does not support Claude, Gemini, OpenCode, or other agents. It does not edit files directly. Grok Build runs locally and Handrail supervises it.

## CLI Install

```sh
cd cli
npm install
npm run build
npm link
```

Handrail controls Grok Build through the Grok CLI's ACP stdio protocol. It spawns Handrail-owned `grok agent --no-leader stdio` children for new turns when needed.

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

The iOS app reads Grok sessions from `~/.grok/sessions`. Chat IDs use the `grok:<session-id>` prefix.

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
- Code stays on the user's machine.
- CLI executes Grok locally.
- iOS receives chat output, changed file names, and git diffs.
- Local network access is required for the MVP.

The token is stored in `~/.handrail/state.json` on the Mac and in Keychain on iOS. iOS stores only non-secret paired-machine metadata in UserDefaults.

## Approval Behavior

For Handrail-started Grok Build turns, the CLI listens for ACP `session/request_permission` requests. It exposes the tool call id to iOS as `approvalId`, emits `approval_required`, and sends approve or deny decisions back to the same ACP request.

The iOS app shows the approval summary and available file context. Approval routing must use the real Grok ACP request id; Handrail does not infer approvals from transcript text.

## Limitations

- Live approval-response release evidence is still required before App Store copy or screenshots claim approval workflows.
- The WebSocket server is plain local-network `ws://`.
- Grok automations are not supported in v1 (empty automation list).
- Physical device install may require a working USB/Wi-Fi debugging tunnel.
- The iOS app stores the pairing token in Keychain and paired-machine metadata in UserDefaults.
- Handrail does not maintain an independent chat store.
- There is no background daemon, cloud relay, account sync, or generic terminal.

## Tests

```sh
cd cli
npm test
npm run e2e   # live WebSocket probe; requires handrail serve
```