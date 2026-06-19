# Handrail Simulator Test Plan

Optimized for iOS Simulator validation on a Mac with a live Handrail CLI server. This plan deliberately excludes physical-device-only flows (camera QR pairing, `devicectl` install, WatchConnectivity) and defers live Grok turn execution to protocol probes where simulator UI automation is unreliable.

**Last run:** 2026-06-19 — [test-artifacts/simulator-test-run-2026-06-19T124200Z/summary.md](../test-artifacts/simulator-test-run-2026-06-19T124200Z/summary.md)  
**Primary targets:** iPhone 17 + iPad Pro 13-inch (M5), **iOS 26.5** (matches Xcode 26.5 SDK)  
**Fallback targets:** same devices on iOS 26.4 (build/launch smoke only; `xcodebuild test` needs 26.5 runtime)  
**Server:** `~/.handrail/state.json` (current port `8788`)

### Simulator UDIDs (this Mac)

| Device | iOS 26.5 UDID |
|--------|----------------|
| iPhone 17 | `339525A5-A57A-4E57-8640-979BD3174878` |
| iPad Pro 13-inch (M5) | `36F91CEE-786D-44C6-9C1F-F5F60D276B25` |

If `xcodebuild test` reports no eligible simulator destinations, install the matching runtime:

```sh
xcodebuild -downloadPlatform iOS
```

---

## Simulator constraints

| Flow | Simulator | Notes |
|------|-----------|-------|
| QR pairing scan | **Skip** | No camera; verify scanner route shows fallback copy only |
| New Chat text entry | **Manual / partial** | `TextEditor` automation is unreliable; validate sheet chrome and disabled states |
| Live approval approve/deny | **Conditional** | Requires a live `waiting_for_approval` chat on the Mac |
| Start / continue / stop Grok turns | **Protocol** | Exercised via `grok_e2e_probe.mjs`, not simulator taps |
| Paired chat list + detail | **Yes** | Requires simulator with valid pairing metadata |
| iOS unit tests | **Yes** | `HandrailTests` — reset corrupt pairing state before iPhone run if needed |

---

## Tier A — Automated gate (required)

Run from repo root unless noted.

### A1. CLI unit tests

```sh
cd cli && npm test
```

**Pass:** all tests green (TypeScript build + Node test runner).

### A2. Grok WebSocket E2E probe

Requires `handrail serve` (or `handrail pair`) running.

```sh
node tools/qa/grok_e2e_probe.mjs
```

**Pass:** `allPassed: true` for handshake, chat list, chat detail, continue, start, stop.

### A3. iOS unit tests — iPhone 17

```sh
xcodebuild test \
  -project ios/Handrail/Handrail.xcodeproj \
  -scheme Handrail \
  -destination 'platform=iOS Simulator,id=339525A5-A57A-4E57-8640-979BD3174878' \
  -only-testing:HandrailTests \
  -derivedDataPath /tmp/handrail-sim-test-iphone
```

**Pass:** `HandrailTests` 48/48 (or current total) with **0 failures**.

If `TransientErrorStateTests` fail with corrupt pairing metadata, reset simulator app data or use a fresh simulator before re-running.

### A3b. Live server connectivity (simulator → Mac host)

Requires `handrail serve` on the Mac. The simulator uses **`127.0.0.1`**, not the LAN IP.

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

**Pass:** `LiveServerConnectivityTests.testSimulatorConnectsToLiveHandrailServer` succeeds (Online + non-empty `grok:` chat list).

### A4. iOS unit tests — iPad Pro 13-inch (M5)

```sh
xcodebuild test \
  -project ios/Handrail/Handrail.xcodeproj \
  -scheme Handrail \
  -destination 'platform=iOS Simulator,id=36F91CEE-786D-44C6-9C1F-F5F60D276B25' \
  -only-testing:HandrailTests \
  -derivedDataPath /tmp/handrail-sim-test-ipad
```

**Pass:** same as A3 on iPad layout tests (`RootLayoutSelectionTests`, window selection).

---

## Tier B — Simulator smoke (required)

```sh
IPHONE_UDID=0E58E7BB-44FA-4BEE-9C94-8FED4C334482 \
IPAD_UDID=43913CAF-14DD-45B6-9633-0A9790474FC7 \
./tools/qa/simulator_sweep.sh
```

**Pass:**

- iPhone + iPad Debug builds succeed
- App installs and launches on both simulators
- Launch screenshots captured under `test-artifacts/qa-simulator-sweep-<stamp>/`

---

## Tier C — UI path walkthrough (simulator-optimized)

Reference: [UI_PATHS.md](../UI_PATHS.md). Execute manually or with simulator automation on a **paired** iPhone 17 simulator while the Mac server is online.

### C1. Unpaired / pairing surfaces

| Step | Expected |
|------|----------|
| Fresh install → Dashboard | Empty pairing state or “pairing needs reset” if stale |
| Tap **Scan Pairing QR** | Scanner opens; shows “No camera is available.” on simulator |
| Settings → scanner fallback | `handrail pair` command visible |

### C2. Dashboard (paired, online)

| Step | Expected |
|------|----------|
| Machine card | Shows `MacBookPro.lan` (or configured name) + **Online** |
| Pinned / All chats | Grok session titles from `grok:<id>` chats |
| Pull to refresh | Sync timestamp updates; chat list refreshes |
| Tap chat row | Opens Chat Detail with transcript blocks |
| Tap **+** | New Chat sheet opens |

### C3. Chats tab

| Step | Expected |
|------|----------|
| Tab bar navigation | Chats, Activity, Alerts, Settings reachable |
| Filter menu | Chronological ↔ project grouping toggles |
| Long-press row | Pin context menu appears |

### C4. New Chat sheet (no live start required)

| Step | Expected |
|------|----------|
| Empty prompt | **Start** disabled |
| Mac offline (stop server) | **Start** disabled + offline copy |
| Valid fields filled | **Start** enabled (do not require successful Grok turn in simulator) |

### C5. Chat Detail

| Step | Expected |
|------|----------|
| Running chat | “Grok is starting…” or streaming transcript |
| Completed / failed | Status-specific empty or failure text |
| Read-only imported chat | No stop / composer controls |

### C6. Activity, Alerts, Approval, Settings

| Step | Expected |
|------|----------|
| Activity empty / populated | Readable empty state; rows navigate to chat when present |
| Alerts | Empty state readable |
| Approval | Empty state when no pending requests |
| Settings | Paired machine, compatibility copy, notification toggles |

---

## Tier D — Optional live UI (when data exists)

Only when the Mac has an active `waiting_for_approval` session:

- Approval tab shows pending request with summary + file context
- Approve / Deny buttons send WebSocket commands

Only when automation can inject composer text:

- New Chat **Start** navigates to Chat Detail after `chat_started`
- Chat Detail composer sends input and streams output

These are **not** simulator gate requirements; protocol coverage in Tier A2 is sufficient for CI-style validation.

---

## Execution checklist

| ID | Tier | Check | Pass criteria |
|----|------|-------|---------------|
| A1 | A | CLI `npm test` | All tests pass |
| A2 | A | `grok_e2e_probe.mjs` | `allPassed: true` |
| A3 | A | iPhone `HandrailTests` | 0 failures |
| A4 | A | iPad `HandrailTests` | 0 failures |
| B1 | B | `simulator_sweep.sh` | Build + launch + screenshots |
| C1–C6 | C | UI walkthrough | Per tables above (manual) |

**Release gate (simulator):** A1–A4 + B1 must pass. Tier C is required before claiming UI polish complete per `AGENTS.md`.

---

## Artifact layout

Each execution run should write:

```
test-artifacts/simulator-test-run-<ISO-stamp>/
  summary.md          # pass/fail table + notes
  cli-npm-test.log
  grok-e2e-summary.json
  iphone-xcode-test.log
  ipad-xcode-test.log
  qa-simulator-sweep/ # symlink or copy from sweep output
```

---

## Related docs

- [TEST_PLAN.md](../TEST_PLAN.md) — full MVP plan (includes physical device)
- [UI_PATHS.md](../UI_PATHS.md) — route map
- [UI_PATH_ISSUES.md](../UI_PATH_ISSUES.md) — known simulator limitations
- [docs/PHASE4_FINDINGS.md](PHASE4_FINDINGS.md) — latest revival validation