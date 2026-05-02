# Live Desktop Data Root-Cause Report

## Strongest Finding

The recurring "simulator live-data blocker" reproduced as a live Codex Desktop/app-server data failure before iOS had a valid event to render. Two controlled real `start_chat` requests sent through the live Handrail WebSocket server both failed with:

```text
Codex Desktop did not become ready to receive this chat after Handrail opened it, so thread-follower-start-turn could not be routed. Try again once the chat is visible in Codex Desktop.
```

Evidence directory: `test-artifacts/live-data-root-cause-20260501T230015Z/`

## Method

- Used the real saved Handrail pairing token from `~/.handrail/state.json`.
- Connected to the live Handrail server on `127.0.0.1:8788`.
- Did not use a fixture server, seeded simulator state, or test-only launch data.
- Used disposable real Desktop chat cwd: `/private/tmp/handrail-live-data-repro`.
- Captured WebSocket messages as NDJSON.
- Captured `node cli/dist/src/index.js chats`.
- Captured read-only SQLite snapshots from `~/.codex/state_5.sqlite` and `~/.codex/logs_2.sqlite`.
- Captured iPad simulator screenshots after the live probe.

The probe script is `tools/qa/live_desktop_data_probe.mjs`.

## Timeline By Layer

### Baseline

- `chat_list` arrived over WebSocket.
- Baseline live list had 50 chats: 5 `running`, 45 `completed`.
- iPad Dashboard rendered live server state: online Mac, 4 running, 0 attention, 0 failed, 19 completed today.
- Evidence:
  - `test-artifacts/live-data-root-cause-20260501T230015Z/summary.json`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/baseline-cli-chats.stdout`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/baseline-desktop-threads.stdout`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/02-ipad-dashboard-online-after-live-probe.jpg`

### Start-Chat Repro

- Probe sent real `start_chat` at `2026-05-01T23:00:16.318Z`.
- Server emitted unrelated push errors first: `Missing HANDRAIL_APNS_TEAM_ID.`
- Server then emitted the Desktop routing error for `thread-follower-start-turn`.
- Server did not emit `chat_started`.
- Server did not emit a chat-linked `chat_event`.
- `node cli/dist/src/index.js chats` did not show a new `HANDRAIL_LIVE_REPRO_START_OK` chat.
- Evidence:
  - `test-artifacts/live-data-root-cause-20260501T230015Z/server-messages.ndjson`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/after-start-chat-cli-chats.stdout`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/after-start-chat-desktop-threads.stdout`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/03-ipad-activity-after-start-chat-repro.jpg`

### Approval Repro

- Probe sent real read-only `start_chat` at `2026-05-01T23:00:25.601Z`.
- Server again emitted unrelated APNs configuration errors.
- Server then emitted the same Desktop routing error for `thread-follower-start-turn`.
- No `chat_started` was emitted for the approval repro chat.
- No `approval_required` message was emitted.
- No `waiting_for_approval` status appeared in `chat_list`.
- iPad Attention showed "No approval selected"; no approval row was available to validate.
- Evidence:
  - `test-artifacts/live-data-root-cause-20260501T230015Z/server-messages.ndjson`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/after-approval-repro-cli-chats.stdout`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/after-approval-repro-desktop-status-logs.stdout`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/04-ipad-attention-after-approval-repro.jpg`

## Cause Classification

### Issue #21: successful `start_chat` does not yield visible iPad success transition

Classification: source/server start path missing.

This run did not reach the "successful `start_chat`" condition. The live server failed before broadcasting `chat_started`, so iOS correctly had no `lastStartedChatId` transition to consume. The concrete failing layer is the Desktop app-server handoff after thread creation: `cli/src/chats.ts` calls `startCodexDesktopConversation`, then waits for Desktop visibility, then `cli/src/codexDesktopIpc.ts` attempts `thread-follower-start-turn`; Codex Desktop returned `no-client-found`, formatted as the observed error.

Secondary finding: APNs configuration errors are broadcast on the same WebSocket stream as command errors. A QA harness that treats any `error` message as the command result can misclassify unrelated push configuration as a simulator/live-data failure.

### Issue #22: Activity has no chat-linked row

Classification: server broadcast missing because start path failed before event creation.

`ChatManager.startChat` would broadcast both `chat_started` and `chat_event` after it has a visible Desktop chat. In this reproduction, neither message was emitted. The iPad Activity screen only showed the existing unlinked `Machine Online` row because no chat-linked event reached the iOS store.

The observed iOS state is downstream-consistent with the WebSocket evidence. This run did not find an iOS Activity decode/store/filtering defect for #22.

### Issue #24: no live `waiting_for_approval` row appears for iPad Dashboard validation

Classification: live condition not produced in this repro; CLI ingestion for approvals is also incomplete.

The controlled approval repro never reached a live Codex turn because the same Desktop routing error happened before the approval prompt could run. Therefore this run cannot claim that Desktop produced an approval state that Handrail failed to display.

Static code inspection shows a second root-cause candidate once Desktop approval state is available: `cli/src/codexSessions.ts` maps live Desktop status from response log events only to `running`, `completed`, `failed`, `stopped`, or `idle`. It does not map any rollout or log shape to `waiting_for_approval`. `cli/src/chats.ts` still throws for `approve` and `deny`. `cli/src/approvals.ts` contains `looksLikeApprovalRequest`, but current live chat listing does not wire it into status extraction or `approval_required` broadcasts.

## Multiple Causes Separated

1. Desktop/app-server routing failure: `thread-follower-start-turn` returns `no-client-found`, preventing real new chats from becoming visible to Handrail.
2. WebSocket error ambiguity: unrelated APNs configuration errors are broadcast as generic `error` messages with no command correlation.
3. Approval ingestion gap: even after Desktop can produce an approval state, current CLI listing/status code has no deterministic `waiting_for_approval` extraction path.

## Verification

- `node --check tools/qa/live_desktop_data_probe.mjs`: passed.
- `cd cli && npm test`: passed, 37/37.
- Focused iPad tests passed, 29/29:

```text
xcodebuild test -project ios/Handrail/Handrail.xcodeproj -scheme Handrail -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -derivedDataPath /private/tmp/handrail-live-data-root-cause-ipad-tests -only-testing:HandrailTests/RootLayoutSelectionTests -only-testing:HandrailTests/ChatListQueryTests -only-testing:HandrailTests/HandrailCommandAvailabilityTests
```

- Live probe completed:

```text
node tools/qa/live_desktop_data_probe.mjs
```

- iPad simulator build and launch passed for `Handrail` on iPad Pro 13-inch (M5), iOS Simulator 26.4.
- Screenshots captured:
  - `test-artifacts/live-data-root-cause-20260501T230015Z/02-ipad-dashboard-online-after-live-probe.jpg`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/03-ipad-activity-after-start-chat-repro.jpg`
  - `test-artifacts/live-data-root-cause-20260501T230015Z/04-ipad-attention-after-approval-repro.jpg`
- GitHub evidence comments:
  - #21: https://github.com/zfifteen/handrail/issues/21#issuecomment-4362068454
  - #22: https://github.com/zfifteen/handrail/issues/22#issuecomment-4362068747
  - #24: https://github.com/zfifteen/handrail/issues/24#issuecomment-4362069040

## Product Invariant Check

The investigation preserved Handrail as a free, local-first iOS remote control for Codex Desktop chats on the user's Mac. It used local Desktop state, local SQLite databases, the local Handrail WebSocket server, and the iPad simulator only. No cloud relay, account state, hosted execution, or non-Codex agent path was introduced.

## Next Focus

The next engineering fix should target the Desktop start-chat handoff first. Until `thread-follower-start-turn` can attach to the newly opened Desktop thread, #21 and #22 cannot produce valid iOS evidence. After that is fixed, run the same probe again and then implement deterministic approval-state ingestion for #24.
