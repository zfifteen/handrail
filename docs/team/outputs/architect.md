# Architect Report

## Strongest Structural Finding

The approval route key is now consistently `chatId + approvalId` across CLI routing and iOS notification identity. The previous iOS local notification request identifier used only `approvalId`, but that value is the raw app-server request id and is scoped to one retained app-server child. Two simultaneous Handrail-started chats can both receive `server-request-1`; using only `approvalId` could collapse or replace distinct approval notifications before the user acts.

## Invariants Preserved Or At Risk

- CLI and iOS share one observable protocol contract: improved. iOS notification scheduling now uses the same route key the mobile approval command sends back.
- Approval actions route a real Desktop pending request id: preserved. `approvalId` remains the app-server request id; no local UUID or transcript-derived marker was introduced.
- Codex Desktop remains the source of truth for visible chat rows: preserved. This run changed local notification identity only.
- Spec documents describe observed behavior without overstating Desktop guarantees: improved. The notification spec now records that approval notification identifiers use `chatId + approvalId`.
- Raw Codex identifiers must not leak into user-facing titles or notification text: preserved. The route key is used only as a local `UNNotificationRequest` identifier, not notification copy.

## Code Or Issue Changes

- Updated `ios/Handrail/Handrail/Utilities/NotificationCoordinator.swift` so approval local notification request identifiers include both `chatId` and `approvalId`.
- Added `NotificationIdentifierTests.testApprovalNotificationIdentifierUsesChatIdAndApprovalId` in `ios/Handrail/HandrailTests/HandrailCommandAvailabilityTests.swift`.
- Updated `docs/spec/handrail-notification-suppression.md` with the approval notification identity contract.
- Slack `#handrail-agents` (`C0B0K6B0T6K`) had no message addressed to `Handrail Architect`; ignored the no-action verification message with Slack Subject `Slack coordination layer verification` and timestamp `1777590711.698899`.
- Updated GitHub issue #2 with the iOS notification identifier correction and the unchanged live evidence gate: `https://github.com/zfifteen/handrail/issues/2#issuecomment-4384308442`.
- No Lead Dev handoff. The narrow architecture patch is complete in this run; #2 still needs live server replacement and real approval-producing Desktop/iOS evidence.

## Required Design Decision

No new product decision is required. #2 remains a live-evidence blocker: closure still needs the running LaunchAgent server to expose the rebuilt CLI, then one real approval-producing Handrail-started Codex Desktop/app-server turn with iOS approve/deny evidence against the app-server request id.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: No product-invariant drift found. The change is local iOS notification request identity plus spec/test coverage; it does not add cloud relay, account state, payment, generic terminal behavior, multi-agent control, non-Codex support, or direct iOS file editing.

## Verification

- Automation memory inspected at `$CODEX_HOME/automations/handrail-architect/memory.md`.
- No architect handoff file was present at `$CODEX_HOME/automations/handrail-architect/handoff.md`.
- `sed -n '1,240p' docs/team/architect.md`: inspected.
- `sed -n '1,240p' docs/team/README.md`: inspected.
- Slack read of `#handrail-agents` (`C0B0K6B0T6K`): no `To: Handrail Architect` request found.
- `gh auth status -h github.com`: authenticated as `zfifteen`.
- `gh issue list --repo zfifteen/handrail --state open --limit 50`: inspected current open blockers.
- `gh issue view 2 --repo zfifteen/handrail --comments`: inspected approval-routing state.
- Direct `xcodebuild test -project ios/Handrail/Handrail.xcodeproj -scheme Handrail -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:HandrailTests/NotificationIdentifierTests` was blocked by CoreSimulatorService access and exited 70.
- XcodeBuildMCP `test_sim -only-testing:HandrailTests/NotificationIdentifierTests` passed 1/1 on iPhone 17, iOS Simulator 26.4.1.
- `git diff --check`: passed.
- `lsof -nP -iTCP:8788 -sTCP:LISTEN`: LaunchAgent server still listening as `node` PID `4657`.
- No iPhone/iPad visible UI screenshot validation was run because this run changed local notification request identity, not visible screens, navigation, decoded screen data, gestures, context menus, sheets, tabs, lists, or empty states.
