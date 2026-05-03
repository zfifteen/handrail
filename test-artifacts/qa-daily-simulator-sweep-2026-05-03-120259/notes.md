# Handrail QA Daily Simulator Sweep 2026-05-03

Run directory: test-artifacts/qa-daily-simulator-sweep-2026-05-03-120259
Started UTC: 2026-05-03T120259Z
Workspace: /Users/velocityworks/IdeaProjects/handrail
Last run: 2026-05-02T12:01:13.381Z

## Inputs inspected

- Automation memory: `/Users/velocityworks/.codex/automations/handrail-simulator-bug-sweep/memory.md`
- Team docs: `docs/team/qa-lead.md`, `docs/team/README.md`
- UI/risk docs: `UI_PATHS.md`, `UI_PATH_ISSUES.md`, `docs/production_readiness_report.md`, `docs/product-invariants.md`, `TEST_PLAN.md`
- Slack search: no `To: Handrail QA Lead` message in `#handrail-agents` after 2026-05-02.
- GitHub issue state: saved to `logs/gh-bug-issues.json` and `logs/gh-all-issues.json`.
- Local branch delta since last run: saved to `logs/git-log-since-last-run.txt`.

## Device targets

- iPhone: iPhone 17, iOS Simulator 26.4.1, UDID `0E58E7BB-44FA-4BEE-9C94-8FED4C334482`.
- iPad: iPad Pro 13-inch (M5), iOS Simulator 26.4.1, UDID `43913CAF-14DD-45B6-9633-0A9790474FC7`.

## Verification

- `gh auth status -h github.com`: authenticated as `zfifteen`.
- `cd cli && npm test`: passed 44/44; log saved at `logs/cli-npm-test.txt`.
- XcodeBuildMCP `test_sim -only-testing:HandrailTests` on iPhone 17: passed 48/48. This re-verifies closed issue #30.
- XcodeBuildMCP `test_sim -only-testing:HandrailTests` on iPad Pro 13-inch (M5): passed 48/48.
- XcodeBuildMCP `build_run_sim` on iPhone 17: build, install, and launch succeeded.
- XcodeBuildMCP `build_run_sim` on iPad Pro 13-inch (M5): build, install, and launch succeeded.
- Shell `simctl` and `tools/qa/simulator_sweep.sh` still cannot access CoreSimulatorService from this automation context; logs saved under `logs/`.

## UI paths walked

- iPhone unpaired Dashboard, Chats unpaired, Pairing Scanner no-camera state, Attention empty, Activity empty, More, Alerts, and Settings pairing repair state.
- iPad paired Dashboard, New Chat disabled state, Chats list, project grouping, Chat Detail running read-only state.

## Findings

- New reproducible bug: iPad Dashboard machine card renders `127.0.0.1:8,788` instead of `127.0.0.1:8788`.
- GitHub issue created: #31 `iPad Dashboard formats local server port with thousands separator`, labels `bug` and `iPad`.
- Evidence screenshot: `mcp-screenshots/ipad-01-dashboard-paired-port-grouping.jpg`.

## Re-verified fixed or done issues

- #30 remains fixed: iPhone `HandrailTests` passed 48/48 after the pairing-isolation test fix.
- #12 remains fixed in the iPad project-grouped Chats view: group headers show readable project names such as `Prime Gap Structure`, not raw slug identifiers.
- New Chat empty state now includes `Add a prompt.` below `Mac online`; the earlier missing-requirement explanation candidate did not reproduce on iPad.
- iPhone tab bar accessibility remains improved: Dashboard, Chats, Attention, Activity, and More are individual accessibility buttons.
- Dashboard header actions remain exposed on iPhone: `New Chat` and `Scan QR Code` are present in the accessibility tree.

## Remaining blockers

- #2 and #24 remain blocked by missing live approval-producing app-server state. The current iPad feed shows running/completed chats but no `waiting_for_approval` row.
- Shell-driven simulator capture remains blocked by CoreSimulatorService access; XcodeBuildMCP was used for simulator validation.

## Product invariant check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found.
