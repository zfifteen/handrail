# Commands

```sh
gh auth status -h github.com
gh issue list -R zfifteen/handrail --label bug --state open --limit 100 --json number,title,labels,state,updatedAt,url
gh issue list -R zfifteen/handrail --state closed --search 'closed:>=2026-05-04 label:bug' --limit 100 --json number,title,labels,state,updatedAt,closedAt,url
gh issue view -R zfifteen/handrail 32 --json number,title,state,labels,comments,closedAt,url
gh issue view -R zfifteen/handrail 2 --json number,title,state,labels,comments,updatedAt,url
gh issue view -R zfifteen/handrail 24 --json number,title,state,labels,comments,updatedAt,url
npm test
lsof -nP -iTCP:8788 -sTCP:LISTEN
node cli/dist/src/index.js chats
xcodebuild -list -project ios/Handrail/Handrail.xcodeproj
axe describe-ui --udid 43913CAF-14DD-45B6-9633-0A9790474FC7
```

XcodeBuildMCP commands used:

```text
list_sims(enabled: true)
session_set_defaults(profile: iphone-17, projectPath: /Users/velocityworks/IdeaProjects/handrail/ios/Handrail/Handrail.xcodeproj, scheme: Handrail, simulatorId: 0E58E7BB-44FA-4BEE-9C94-8FED4C334482, bundleId: com.velocityworks.Handrail)
test_sim(extraArgs: [])
build_run_sim(extraArgs: [])
tap(label: Scan Pairing QR)
tap(label: Close)
tap(label: Chats)
tap(label: Attention)
tap(label: Activity)
tap(label: More)
tap(label: Settings)
session_set_defaults(profile: ipad-pro-13, projectPath: /Users/velocityworks/IdeaProjects/handrail/ios/Handrail/Handrail.xcodeproj, scheme: Handrail, simulatorId: 43913CAF-14DD-45B6-9633-0A9790474FC7, bundleId: com.velocityworks.Handrail)
test_sim(extraArgs: [])
build_run_sim(extraArgs: [])
tap(label: Chats)
tap(label: Dashboard)
tap(label: New chat)
tap(label: Attention)
tap(label: Activity)
tap(label: Alerts)
tap(label: Settings)
screenshot(returnFormat: path)
```
