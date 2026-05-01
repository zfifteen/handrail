# QA Lead Report

## Strongest Evidence Finding

The Release APNs source configuration is fixed, but GitHub issue #25 is not closable yet: a real Release archive cannot be signed with the current local provisioning profile because it lacks Push Notifications and the `aps-environment` entitlement.

## Verified Behavior

- Slack inbox checked for `#handrail-agents` (`C0B0K6B0T6K`): no recent message was addressed to `Handrail QA Lead`. The only recent operational message was a no-action coordination verification addressed to `Handrail agents` at `2026-04-30 19:11:51 EDT`, TS `1777590711.698899`.
- QA handoff checked at `/Users/velocityworks/.codex/automations/handrail-qa-lead/handoff.md`: current handoff only confirms the new lead-dev-to-QA handoff mechanism and states no product behavior changed.
- `gh auth status -h github.com` is authenticated as `zfifteen` for `zfifteen/handrail`.
- `plutil -p ios/Handrail/Handrail/Handrail.entitlements` reports `aps-environment => production`.
- `plutil -lint ios/Handrail/Handrail/Handrail.entitlements` passes.
- Release build settings with `xcodebuild -project ios/Handrail/Handrail.xcodeproj -scheme Handrail -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/handrail-qa-buildsettings -showBuildSettings` report:
  - `CODE_SIGN_ENTITLEMENTS = Handrail/Handrail.entitlements`
  - `CONFIGURATION = Release`
  - `PRODUCT_BUNDLE_IDENTIFIER = com.velocityworks.Handrail`
  - `INFOPLIST_KEY_NSLocalNetworkUsageDescription = Handrail connects to the desktop CLI on your local network.`

## Missing Evidence Or Regressions

- Issue #25 remains open because its acceptance check requires a signed Release archive entitlement inspection. The attempted archive failed during provisioning: `iOS Team Provisioning Profile: com.velocityworks.Handrail` does not include Push Notifications or the `aps-environment` entitlement.
- Simulator validation was not required for the current handoff because it touched only automation coordination, not visible iPhone/iPad UI, navigation, decoded screen data, gestures, context menus, sheets, tabs, lists, or empty states.
- Current open bug list still includes iPhone accessibility/reliability issues #4, #7, #8, #9, #10, #11, #12, #16, #18, #19, #27 and iPad issues #17, #21, #22, #23, #24.
- Existing unrelated user change preserved: `docs/team/outputs/pm.md` was already modified before this QA report update and was not edited.

## Code, Test, Or Issue Changes

- Updated GitHub issue #25 body and left a QA verification comment with the exact remaining blocker: a production-capable distribution/TestFlight/App Store provisioning profile is required before `codesign -d --entitlements :- <App.app>` can prove the signed app carries `aps-environment = production`.
- Updated this report: `docs/team/outputs/qa-lead.md`.

## Verification

- Read QA/team contracts: `docs/team/qa-lead.md`, `docs/team/README.md`.
- Read QA memory and handoff:
  - `/Users/velocityworks/.codex/automations/handrail-qa-lead/memory.md`
  - `/Users/velocityworks/.codex/automations/handrail-qa-lead/handoff.md`
- Reviewed project QA inputs:
  - `TEST_PLAN.md`
  - `UI_PATHS.md`
  - `UI_PATH_ISSUES.md`
  - `FEATURE_ROADMAP.md`
  - `docs/production_readiness_report.md`
  - `docs/team/outputs/lead-dev.md`
  - `docs/team/outputs/architect.md`
- Reviewed GitHub bug queue with `gh issue list -R zfifteen/handrail --label bug --limit 100`.
- Ran Release entitlement/source checks:
  - `plutil -p ios/Handrail/Handrail/Handrail.entitlements`
  - `plutil -lint ios/Handrail/Handrail/Handrail.entitlements`
  - `rg -n "aps-environment|CODE_SIGN_ENTITLEMENTS|INFOPLIST_KEY_NSLocalNetworkUsageDescription|Release" ios/Handrail/Handrail.xcodeproj/project.pbxproj ios/Handrail/Handrail/Handrail.entitlements`
- Ran archive check:
  - `xcodebuild archive -project ios/Handrail/Handrail.xcodeproj -scheme Handrail -configuration Release -destination 'generic/platform=iOS' -archivePath /private/tmp/handrail-qa-release.xcarchive -derivedDataPath /private/tmp/handrail-qa-archive-derived`
  - Result: failed at provisioning because the local team profile lacks Push Notifications and `aps-environment`.
