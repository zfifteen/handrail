# Handrail QA Daily Simulator Sweep - 2026-05-02T12:02:33Z

## Targets

- iPhone: iPhone 17, iOS Simulator 26.4.1, UDID `0E58E7BB-44FA-4BEE-9C94-8FED4C334482`.
- iPad: iPad Pro 13-inch (M5), iOS Simulator 26.4.1, UDID `43913CAF-14DD-45B6-9633-0A9790474FC7`.
- App bundle: `com.velocityworks.Handrail`.
- Local server: `node` listening on TCP `*:8788`.

## Commands And Results

- Read automation memory: `$CODEX_HOME/automations/handrail-simulator-bug-sweep/memory.md`.
- Inspected `docs/team/qa-lead.md`, `docs/team/README.md`, `UI_PATHS.md`, `UI_PATH_ISSUES.md`, `docs/production_readiness_report.md`, `docs/product-invariants.md`, and `TEST_PLAN.md`.
- Slack public search for `"To: Handrail QA Lead" in:<#C0B0K6B0T6K> after:2026-05-01`: no results.
- `gh auth status`: authenticated as `zfifteen`.
- `gh issue list -R zfifteen/handrail --state all --label bug --limit 100 --json number,title,state,labels,updatedAt,closedAt`: saved to `gh-bug-issues.json`.
- Shell `xcrun simctl list devices available`: failed with CoreSimulatorService access error; saved to `simctl-list-devices.log`.
- Shell `tools/qa/simulator_sweep.sh`: failed on the same shell `simctl` access path; saved to `simulator_sweep_script.log`.
- XcodeBuildMCP `list_sims`: succeeded and listed iOS 26.4 simulators.
- XcodeBuildMCP `build_run_sim` on iPhone 17: passed.
- XcodeBuildMCP iPhone UI taps and screenshots: completed unpaired Dashboard, scanner, Chats, Attention, Activity, More, Alerts, Settings, and pairing reset paths.
- XcodeBuildMCP `build_run_sim` on iPad Pro 13-inch (M5): passed.
- XcodeBuildMCP iPad UI taps and screenshots: completed paired Dashboard, Chats, project grouping, Chat Detail, New Chat disabled state, Activity, Alerts, Settings, and Approval empty surface.
- `cd cli && npm test`: passed 40/40.
- XcodeBuildMCP `test_sim -only-testing:HandrailTests` on iPad Pro 13-inch (M5): passed 48/48.
- XcodeBuildMCP `test_sim -only-testing:HandrailTests` on iPhone 17: failed 45/48.
- XcodeBuildMCP `test_sim -only-testing:HandrailTests/TransientErrorStateTests` on iPhone 17: failed 4/7.

## UI Path Notes

- iPhone was unpaired. The unpaired Dashboard and Chats paths rendered cleanly.
- iPhone scanner route showed `No camera is available.`, matching simulator expectation.
- iPhone Settings showed `Pairing needs reset` for stored metadata without a Keychain token, then `Reset Pairing` removed the repair card from the app UI.
- iPad was paired to `MacBookPro.lan` at `127.0.0.1:8788` and showed Online state.
- iPad Dashboard showed running, attention, failed, and completed metrics without lower-content overlap.
- iPad Chats project grouping displayed readable project names such as `Prime Gap Structure`, `Understand Https Deepmind Google Models Gemma`, and `handrail`; raw slug identifiers were not observed.
- iPad Chat Detail displayed readable Codex turns for `Defend the math`.
- iPad New Chat showed `Start` disabled and footer `Add a prompt.` with Mac online.
- iPad Activity showed the current machine-level event.
- iPad Alerts empty state and Settings rendered without visible regressions.
- iPad Attention currently routes to an approval-review empty state titled `Approval`, with `No approval selected`; this was not filed as a new bug in this sweep because existing iPad issue #24 and product spec #6 already cover approval/attention stabilization.

## Reverified Closed Or Claimed-Fixed Issues

- #12: project-grouped chat names are readable on iPad; evidence `ipad-chats-project-mode.jpg`.
- #19: corrupt/missing pairing token repair path is visible on iPhone Settings; evidence `iphone-settings.jpg` and `iphone-settings-after-reset.jpg`.
- #21/#22/#29: current paired iPad feed contains live started-chat evidence from prior closure runs; no regression was observed in Dashboard, Chats, Activity, or Chat Detail.
- #23: no stale approval selection was observed while navigating between Dashboard, Chats, Chat Detail, Activity, Alerts, and Settings.
- #16/#18: no visible regression was directly exercisable from current live UI state; issue evidence and current test coverage were inspected through GitHub and the passing iPad suite.

## New Finding

- Created GitHub issue #30 for iPhone simulator test isolation failure: iPhone `TransientErrorStateTests` inherit persisted corrupt pairing metadata and fail deterministically on this simulator state.

## Remaining Blockers

- Full shell sweep script remains blocked in this automation sandbox by shell `simctl` CoreSimulatorService access, while XcodeBuildMCP simulator control works.
- iPhone paired chat-list/detail paths could not be walked because the selected iPhone 17 simulator had no valid paired machine state.
- #24 remains blocked by missing live `waiting_for_approval` state from first-class approval routing.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: no product-invariant drift found.
