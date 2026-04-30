# QA Lead Report

## Strongest Evidence Finding

Simulator smoke validation is now executable: the iOS app builds, installs, launches, and produces screenshots on both iPhone and iPad simulators (iPhone 17 iOS 26.4 and iPad Pro 13-inch (M5) iOS 26.4) using `tools/qa/simulator_sweep.sh` on 2026-04-30.

## Verified Behavior

- Simulator build/install/launch succeeds for iPhone+iPad, with screenshot evidence:
  - `test-artifacts/qa-simulator-sweep-2026-04-30-175240/iphone-launch.png`
  - `test-artifacts/qa-simulator-sweep-2026-04-30-175240/ipad-launch.png`
- CLI unit + integration-style tests pass (36/36), including:
  - Codex Desktop IPC frame encoding/decoding helpers.
  - Desktop thread deep-link formatting.
  - WebSocket server behavior for pairing, refresh, stop, push-token registration, and polling-triggered broadcasts.
- UI path documentation exists with screenshot evidence:
  - `UI_PATHS.md` (documented iPhone UI paths; captured 2026-04-28).
  - `UI_PATH_ISSUES.md` (documented gaps + screenshots; walkthrough 2026-04-28).

## Missing Evidence Or Regressions

- Full UI-path walkthrough in simulator is still missing for this run (Dashboard → Chats → New Chat → Chat Detail → Attention → Activity → Alerts → Settings), and no existing bug issues were re-verified/closed yet.
- **App Store blockers to track:**
  - Release APNs entitlement is still `development` (`ios/Handrail/Handrail/Handrail.entitlements`). (GitHub issue #25)
  - Privacy policy URL + document are absent from the repo. (GitHub issue #26)
- **Open bug surface (selected):**
  - iOS accessibility: issues #7, #8, #9, #11.
  - iOS UX/data: issues #10, #12, #4, #16, #18, #19.
  - iPad routing/state: issues #17, #21, #22, #23, #24.

## Code, Test, Or Issue Changes

- Updated `docs/team/qa-lead.md` so the QA lead automation explicitly owns GitHub bug issue triage + verification + closing/reopening with evidence.
- Added `tools/qa/simulator_sweep.sh` to generate deterministic simulator launch evidence into `test-artifacts/`.
- Updated `docs/production_readiness_report.md` to move `NSLocalNetworkUsageDescription` from **[BLOCKER]** to **[VERIFY]**, reflecting that it is already set via generated Info.plist build settings in `ios/Handrail/Handrail.xcodeproj/project.pbxproj`.
- Created GitHub issues:
  - #25 “App Store blocker: Release APNs entitlement must be production”
  - #26 “App Store blocker: Add privacy policy URL + document”

## Verification

- Ran: `cd cli && npm test` (PASS, 36 tests).
- Ran: `IPHONE_UDID=0E58E7BB-44FA-4BEE-9C94-8FED4C334482 IPAD_UDID=43913CAF-14DD-45B6-9633-0A9790474FC7 tools/qa/simulator_sweep.sh`
- Reviewed inputs:
  - `TEST_PLAN.md`
  - `UI_PATHS.md`
  - `UI_PATH_ISSUES.md`
  - `docs/production_readiness_report.md`
  - `gh issue list -R zfifteen/handrail`
