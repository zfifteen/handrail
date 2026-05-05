# Handrail QA Daily Simulator Sweep - 2026-05-05

## Summary

The strongest supported finding is that the current branch passes the broad CLI and iOS simulator confidence checks, and the iPad sidebar accessibility bug #32 remains fixed in simulator. No new reproducible user-facing bug was found.

#24 remains blocked by #2 live approval evidence. The local server on port 8788 still shows running, idle, and completed chats only; no `waiting_for_approval` row was available for iPad Dashboard closure evidence.

## Inputs Reviewed

- Automation memory: `$CODEX_HOME/automations/handrail-simulator-bug-sweep/memory.md`
- `docs/team/qa-lead.md`
- `docs/team/README.md`
- `UI_PATHS.md`
- `UI_PATH_ISSUES.md`
- `docs/production_readiness_report.md`
- `docs/product-invariants.md`
- `TEST_PLAN.md`
- Git commits since `2026-05-04T12:02:03Z`: `be5e79c Fix iPad sidebar accessibility`, `a053c96 Scope approval routing by chat`
- Slack public search for `"To: Handrail QA Lead" in:#handrail-agents` after `1777896123`: no results
- GitHub issue state through local `gh` only

## Devices

- iPhone 17, iOS Simulator 26.4.1, UDID `0E58E7BB-44FA-4BEE-9C94-8FED4C334482`
- iPad Pro 13-inch (M5), iOS Simulator 26.4.1, UDID `43913CAF-14DD-45B6-9633-0A9790474FC7`
- App bundle: `com.velocityworks.Handrail`
- Xcode project: `ios/Handrail/Handrail.xcodeproj`
- Scheme: `Handrail`

## Commands And Tool Checks

- `gh auth status -h github.com`: authenticated as `zfifteen`
- `gh issue list -R zfifteen/handrail --label bug --state open --limit 100 --json number,title,labels,state,updatedAt,url`: open bugs were #24 and #25
- `gh issue list -R zfifteen/handrail --state closed --search 'closed:>=2026-05-04 label:bug' --limit 100 --json number,title,labels,state,updatedAt,closedAt,url`: closed bug since last run was #32
- `npm test` in `cli/`: passed 46/46; log `logs/cli-npm-test.log`
- `lsof -nP -iTCP:8788 -sTCP:LISTEN`: live server is `node` PID `4657`; log `logs/lsof-8788.log`
- `node cli/dist/src/index.js chats`: no `waiting_for_approval` row; log `logs/live-server-chats.log`
- `xcodebuild -list -project ios/Handrail/Handrail.xcodeproj`: listed `Handrail` and `HandrailTests`, while shell CoreSimulatorService access still logged service errors; log `logs/xcodebuild-list.log`
- `axe describe-ui --udid 43913CAF-14DD-45B6-9633-0A9790474FC7`: unavailable in shell (`command not found`); log `logs/ipad-axe-chats.txt`
- XcodeBuildMCP `test_sim` on iPhone 17: passed 50/50
- XcodeBuildMCP `build_run_sim` on iPhone 17: succeeded
- XcodeBuildMCP `test_sim` on iPad Pro 13-inch (M5): passed 50/50
- XcodeBuildMCP `build_run_sim` on iPad Pro 13-inch (M5): succeeded

## iPhone Walk

The iPhone simulator launched in unpaired pairing-repair state.

- Dashboard unpaired state: `mcp-screenshots/iphone-01-dashboard.jpg`
- Pairing Scanner no-camera state: `mcp-screenshots/iphone-02-pairing-scanner.jpg`
- Chats unpaired state: `mcp-screenshots/iphone-03-chats-unpaired.jpg`
- Attention empty state: `mcp-screenshots/iphone-04-attention-empty.jpg`
- Activity empty state: `mcp-screenshots/iphone-05-activity-empty.jpg`
- More root and Alerts route: `mcp-screenshots/iphone-06-more.jpg`, `mcp-screenshots/iphone-07-more-root.jpg`
- Settings pairing repair state: `mcp-screenshots/iphone-08-settings-unpaired.jpg`

The visible repair state for missing stored Keychain pairing token was clear and actionable: Settings showed `Pairing needs reset` and `Reset Pairing`.

## iPad Walk

The iPad simulator launched paired and online against `127.0.0.1:8788`.

- Dashboard paired state: `mcp-screenshots/ipad-01-dashboard.jpg`
- Chats list: `mcp-screenshots/ipad-02-chats.jpg`
- Project-name display remains human-readable; no raw slug regression was visible: `mcp-screenshots/ipad-03-project-grouping.jpg`
- Chat Detail: `mcp-screenshots/ipad-04-chat-detail.jpg`
- Sidebar after Chat Detail: `mcp-screenshots/ipad-05-sidebar-after-chat-detail.jpg`
- Attention empty state: `mcp-screenshots/ipad-06-attention-empty.jpg`
- Activity list: `mcp-screenshots/ipad-07-activity.jpg`
- Alerts empty state: `mcp-screenshots/ipad-08-alerts.jpg`
- Settings paired state: `mcp-screenshots/ipad-09-settings.jpg`
- New Chat disabled state with `Add a prompt.` footer: `mcp-screenshots/ipad-10-new-chat.jpg`

For #32, XcodeBuildMCP label taps succeeded for `Dashboard`, `Chats`, `Attention`, `Activity`, `Alerts`, and `Settings` after opening the iPad sidebar.

## GitHub Issues

- Updated #32 with a QA daily sweep re-verification comment: https://github.com/zfifteen/handrail/issues/32#issuecomment-4379096246
- No new issues were created.
- #24 remains open and blocked by #2 live approval evidence.
- #25 remains open and blocked by Release/APNs signing evidence outside simulator scope.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found.
