# QA Daily Simulator Sweep 2026-05-04

Run timestamp UTC: 2026-05-04T120255Z
Local timestamp: 2026-05-04T080255-0400

## Commands

- sed -n '1,240p' docs/team/qa-lead.md
- sed -n '1,240p' docs/team/README.md
- sed -n '1,260p' UI_PATHS.md
- sed -n '1,260p' UI_PATH_ISSUES.md
- sed -n '1,260p' docs/production_readiness_report.md
- sed -n '1,220p' docs/product-invariants.md
- sed -n '1,140p' TEST_PLAN.md
- git status --short
- git log --since='2026-05-03T12:02:07Z' --oneline --decorate --max-count=30
- gh auth status -h github.com
- gh issue list -R zfifteen/handrail --label bug --limit 100 --json number,title,state,labels,updatedAt,closedAt,url
- gh issue list -R zfifteen/handrail --state closed --search 'updated:>=2026-05-03T12:02:07Z label:bug' --limit 50 --json number,title,state,labels,updatedAt,closedAt,url
- gh issue view -R zfifteen/handrail 31 --comments --json number,title,state,labels,updatedAt,closedAt,comments,url
- gh issue view -R zfifteen/handrail 24 --comments --json number,title,state,labels,updatedAt,comments,url
- cd cli && npm test
- xcrun simctl list devices available
- IPHONE_UDID=0E58E7BB-44FA-4BEE-9C94-8FED4C334482 IPAD_UDID=43913CAF-14DD-45B6-9633-0A9790474FC7 tools/qa/simulator_sweep.sh
- XcodeBuildMCP list_sims
- XcodeBuildMCP test_sim on iPhone 17 (`0E58E7BB-44FA-4BEE-9C94-8FED4C334482`)
- XcodeBuildMCP test_sim on iPad Pro 13-inch (M5) (`43913CAF-14DD-45B6-9633-0A9790474FC7`)
- XcodeBuildMCP build_run_sim on iPad Pro 13-inch (M5)
- XcodeBuildMCP snapshot_ui / tap / screenshot for iPad Dashboard, Chats, Chat Detail, and project grouping
- XcodeBuildMCP test_sim -only-testing:HandrailTests/PairedMachineFormattingTests on iPad Pro 13-inch (M5)
- XcodeBuildMCP build_run_sim / launch_app_sim / snapshot_ui / tap / screenshot for iPhone Dashboard, Chats, Attention, Activity, More, Alerts, Settings, and Pairing Scanner
- Slack read channel `C0B0K6B0T6K` after `1777809727`
- gh issue create -R zfifteen/handrail --title "iPad sidebar navigation items are missing from accessibility tree" --body-file test-artifacts/qa-daily-simulator-sweep-2026-05-04-120255/logs/ipad-sidebar-accessibility-issue-body.md --label bug --label iPad
