# Simulator Connectivity Test — 2026-06-19T09:05:04Z

## Server

| Item | Value |
|------|-------|
| `handrail serve` | Running on port **8788** |
| Simulator host path | `ws://127.0.0.1:8788` |
| Pairing token | From `~/.handrail/state.json` |

## Results

| Step | Result | Evidence |
|------|--------|----------|
| Host localhost WebSocket probe | **PASS** | 50 chats after `machine_status` — `host-localhost-probe.log` |
| `LiveServerConnectivityTests` on iPhone 17 (iOS 26.5) | **PASS** | `** TEST SUCCEEDED **` — xcresult `Test-Handrail-2026.06.19_09-05-16--0400.xcresult` |
| App install + launch (unpaired UI) | **PASS** | Launch reached notification permission prompt — `iphone-after-connectivity-test-launch.png` |

## What was validated

The XCTest pairs against `127.0.0.1:8788` (the path the iOS Simulator uses to reach the Mac host), waits for `machine_status` + `chat_list`, and asserts:

- `connectionText == "Online"`
- `chats.count > 0`
- every chat id starts with `grok:`

## Command

```sh
HANDRAIL_PAIRING_TOKEN="$(python3 -c 'import json,pathlib; print(json.loads(pathlib.Path.home().joinpath(".handrail/state.json").read_text())["pairingToken"])')" \
HANDRAIL_HOST=127.0.0.1 \
HANDRAIL_PORT=8788 \
xcodebuild test \
  -project ios/Handrail/Handrail.xcodeproj \
  -scheme Handrail \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=339525A5-A57A-4E57-8640-979BD3174878' \
  -only-testing:HandrailTests/LiveServerConnectivityTests \
  -derivedDataPath /tmp/handrail-sim-connectivity-test
```

## Note on physical iPhone vs simulator

The simulator reaches the Mac via **`127.0.0.1`**. A physical iPhone must use the Mac’s LAN IP (currently **`192.168.1.149:8788`**) and requires iOS Local Network permission (fixed in v0.1.5+).