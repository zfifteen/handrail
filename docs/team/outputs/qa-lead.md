# QA Lead Report

## Strongest Evidence Finding

The 2026-05-05 daily simulator sweep found no new reproducible Handrail UI bug. The current branch passed `cli` tests 46/46, iPhone simulator `HandrailTests` 50/50, and iPad simulator `HandrailTests` 50/50. The iPad sidebar accessibility fix #32 remains fixed under live simulator navigation.

## Verified Behavior

- Slack public search found no new `To: Handrail QA Lead` request in `#handrail-agents` after the last daily sweep timestamp.
- `gh auth status -h github.com` is authenticated as `zfifteen`; GitHub reads and the #32 comment used local `gh` only.
- iPhone 17, iOS Simulator 26.4.1, launched and exercised unpaired Dashboard, Pairing Scanner no-camera, Chats unpaired, Attention empty, Activity empty, More, Alerts, and Settings pairing repair.
- iPad Pro 13-inch (M5), iOS Simulator 26.4.1, launched paired and online against `127.0.0.1:8788`.
- iPad paths covered Dashboard, Chats, Chat Detail, New Chat disabled state, Activity, Alerts, Settings, and sidebar navigation.
- #32 remains fixed: label taps succeeded for `Dashboard`, `Chats`, `Attention`, `Activity`, `Alerts`, and `Settings`.
- #12 remains fixed in the visible iPad chat list: project names were readable, including `Prime Gap Structure`, rather than raw slug identifiers.

## Missing Evidence Or Regressions

- #24 remains blocked by #2 live approval evidence. The live server had no `waiting_for_approval` row, so the iPad Dashboard approval-row closure path was not available.
- #25 remains outside simulator scope because it requires Release/APNs signing evidence.
- Shell `xcodebuild` still logs CoreSimulatorService access errors in this automation context, even though XcodeBuildMCP simulator build/test/run worked.

## Code, Test, Or Issue Changes

- Added daily sweep artifacts under `test-artifacts/qa-daily-simulator-sweep-2026-05-05-120132/`.
- Commented on #32 with QA re-verification evidence: https://github.com/zfifteen/handrail/issues/32#issuecomment-4379096246
- No product source code was edited.
- Existing local modifications in `docs/production_readiness_report.md` and `docs/team/outputs/pm.md` were preserved.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found.

## Verification

- `npm test` in `cli/`: passed 46/46.
- XcodeBuildMCP `test_sim` on iPhone 17: passed 50/50.
- XcodeBuildMCP `build_run_sim` on iPhone 17: succeeded.
- XcodeBuildMCP `test_sim` on iPad Pro 13-inch (M5): passed 50/50.
- XcodeBuildMCP `build_run_sim` on iPad Pro 13-inch (M5): succeeded.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN`: live server listener is `node` PID `4657`.
- `node cli/dist/src/index.js chats`: no `waiting_for_approval` row.
- Evidence notes and screenshots: `test-artifacts/qa-daily-simulator-sweep-2026-05-05-120132/`.
