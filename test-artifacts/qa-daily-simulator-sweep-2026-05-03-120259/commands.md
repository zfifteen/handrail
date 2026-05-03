Commands and tool actions will be appended as run evidence.
gh auth status -h github.com
gh issue list -R zfifteen/handrail --state all --label bug --limit 100 --json number,title,state,labels,updatedAt,closedAt,url
gh issue list -R zfifteen/handrail --state all --limit 100 --json number,title,state,labels,updatedAt,closedAt,milestone,url
git log --since=2026-05-02T12:01:13Z --oneline --decorate --all --max-count=80
xcodebuild -list -project ios/Handrail/Handrail.xcodeproj
xcrun simctl list devices available
tools/qa/simulator_sweep.sh
Slack search: "To: Handrail QA Lead" in #handrail-agents after 2026-05-02
XcodeBuildMCP session_set_defaults: iPhone 17, iOS Simulator 26.4.1, UDID 0E58E7BB-44FA-4BEE-9C94-8FED4C334482
XcodeBuildMCP test_sim -only-testing:HandrailTests on iPhone 17: passed 48/48
XcodeBuildMCP build_run_sim on iPhone 17: succeeded
XcodeBuildMCP snapshot_ui/tap/screenshot: iPhone Dashboard, Pairing Scanner, Chats, Attention, Activity, Alerts, Settings
XcodeBuildMCP session_set_defaults: iPad Pro 13-inch (M5), iOS Simulator 26.4.1, UDID 43913CAF-14DD-45B6-9633-0A9790474FC7
XcodeBuildMCP test_sim -only-testing:HandrailTests on iPad Pro 13-inch (M5): passed 48/48
XcodeBuildMCP build_run_sim on iPad Pro 13-inch (M5): succeeded
XcodeBuildMCP snapshot_ui/tap/screenshot: iPad Dashboard, New Chat, Chats, project grouping, Chat Detail
gh issue create -R zfifteen/handrail --title "iPad Dashboard formats local server port with thousands separator" --body-file /tmp/handrail-issue-ipad-port-grouping.md --label bug --label iPad
