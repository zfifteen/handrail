# QA Lead Report

## Strongest Evidence Finding

Issue #27 remains correctly closed: independent QA validation on iPhone 17 confirmed that New Chat and Chat Detail no longer replay the historical `Codex Desktop did not become ready` banner when opened.

## Verified Behavior

- Slack inbox checked for `#handrail-agents` (`C0B0K6B0T6K`) after the previous QA run timestamp; no message was addressed to `Handrail QA Lead`.
- QA handoff checked at `/Users/velocityworks/.codex/automations/handrail-qa-lead/handoff.md`; no handoff file is currently present.
- Reviewed the Lead Dev report's QA handoff note for issue #27 and performed the requested iPhone spot-check.
- `gh auth status -h github.com` is authenticated as `zfifteen` for `zfifteen/handrail`.
- Opened Dashboard -> New chat on iPhone 17 simulator: no stale readiness error banner appeared before a fresh request.
- Opened Dashboard -> `Analyze notification plumbing` Chat Detail on iPhone 17 simulator: no stale historical error banner appeared.

## Missing Evidence Or Regressions

- Issue #27 is verified from QA's side; no reopen condition was found.
- The full acceptance path for "newly-triggered failing request still appears in Alerts" was not re-exercised in UI during this run because the Lead Dev handoff requested the narrower stale-banner spot-check. The store-level regression tests covering scoped transient errors passed.
- Existing unrelated local changes remain present in source, specs, and role reports. This QA run preserved them.

## Code, Test, Or Issue Changes

- Added QA verification comment to GitHub issue #27: https://github.com/zfifteen/handrail/issues/27#issuecomment-4358000270
- Added simulator screenshots:
  - `test-artifacts/qa-lead-issue27-2026-05-01/01-dashboard-before-new-chat.jpg`
  - `test-artifacts/qa-lead-issue27-2026-05-01/02-new-chat-no-stale-error.jpg`
  - `test-artifacts/qa-lead-issue27-2026-05-01/03-chat-detail-no-stale-error.jpg`
- Updated this report: `docs/team/outputs/qa-lead.md`.

## Verification

- Read QA/team contracts:
  - `docs/team/qa-lead.md`
  - `docs/team/README.md`
- Read automation memory:
  - `/Users/velocityworks/.codex/automations/handrail-qa-lead/memory.md`
- Reviewed QA inputs and recent role reports:
  - `TEST_PLAN.md`
  - `UI_PATHS.md`
  - `UI_PATH_ISSUES.md`
  - `docs/production_readiness_report.md`
  - `docs/team/outputs/lead-dev.md`
  - `docs/team/outputs/architect.md`
- Reviewed open issue queue with local `gh`:
  - `gh issue list -R zfifteen/handrail --state open --limit 100 --json number,title,labels,milestone,updatedAt,url`
- Reviewed closed issue #27 with local `gh`:
  - `gh issue view -R zfifteen/handrail 27 --comments --json number,title,state,labels,body,comments,url`
- Ran CLI tests:
  - `cd cli && npm test`
  - Result: 36/36 passed.
- Ran targeted Swift simulator tests:
  - XcodeBuildMCP `test_sim` on iPhone 17 / iOS 26.4 with `-only-testing:HandrailTests/TransientErrorStateTests`
  - Result: passed.
- Ran iPhone simulator validation:
  - XcodeBuildMCP `build_run_sim` for project `/Users/velocityworks/IdeaProjects/handrail/ios/Handrail/Handrail.xcodeproj`, scheme `Handrail`, simulator `iPhone 17` (`0E58E7BB-44FA-4BEE-9C94-8FED4C334482`)
  - Result: build, install, and launch succeeded.
