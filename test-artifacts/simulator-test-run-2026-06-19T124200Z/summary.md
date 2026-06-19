# Simulator Test Run — 2026-06-19T12:42:00Z

Plan: [docs/SIMULATOR_TEST_PLAN.md](../../docs/SIMULATOR_TEST_PLAN.md)

## Environment

| Item | Value |
|------|-------|
| Xcode | 26.5 (17F42) |
| Handrail server | `ws://127.0.0.1:8788` (running) |
| iPhone simulator | iPhone 17, iOS **26.5**, UDID `339525A5-A57A-4E57-8640-979BD3174878` |
| iPad simulator | iPad Pro 13-inch (M5), iOS **26.5**, UDID `36F91CEE-786D-44C6-9C1F-F5F60D276B25` |
| Legacy sweep sims | iOS 26.4 UDIDs (build smoke only) |

**Host fix applied:** Downloaded iOS 26.5 Simulator runtime (`xcodebuild -downloadPlatform iOS`) so `xcodebuild test` could resolve destinations against Xcode 26.5 SDK.

## Results

| ID | Tier | Check | Result | Evidence |
|----|------|-------|--------|----------|
| A1 | A | CLI `npm test` | **PASS** | 60/60 — `cli-npm-test.log` |
| A2 | A | `grok_e2e_probe.mjs` | **PASS** | 6/6 checks — `grok-e2e-summary.json` |
| A3 | A | iPhone `HandrailTests` | **PASS** | 68/68 — `iphone-xcode-test.log` |
| A4 | A | iPad `HandrailTests` | **PASS** | 68/68 — `ipad-xcode-test.log` |
| B1 | B | `simulator_sweep.sh` | **PASS** | iOS 26.4 build + launch + screenshots — `qa-simulator-sweep/` |
| C1–C6 | C | UI walkthrough | **PARTIAL** | Fresh iOS 26.5 install shows notification permission prompt (`iphone-dashboard.png`); full paired navigation not re-walked this run |

## Grok E2E highlights

- 50 Grok chats in list; all ids `grok:*`
- Sample detail transcript: 659 lines with Grok blocks
- Start + stop probe succeeded on ephemeral workdir

## Simulator smoke notes

- iOS 26.4 sweep captured launch splash on both iPhone and iPad (`iphone-launch.png`, `ipad-launch.png`).
- iOS 26.5 fresh install reached first-run notification permission dialog (expected Tier C1/C6 surface).

## Gate verdict

**Automated simulator gate: PASS** (A1–A4 + B1).

Tier C manual UI walkthrough remains recommended before UI polish sign-off per `AGENTS.md`.

## Artifacts in this folder

- `cli-npm-test.log`
- `grok-e2e.log`, `grok-e2e-summary.json`
- `iphone-xcode-test.log`, `ipad-xcode-test.log`
- `iphone-dashboard.png`
- `qa-simulator-sweep/` → `../qa-simulator-sweep-2026-06-19-083418/`