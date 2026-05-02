# Handrail iPhone Screenshot Plan

Last updated: 2026-05-02
Target: iPhone App Store readiness milestone

## Rule

Capture only iPhone screenshots that show verified Handrail behavior. Do not use iPad, watchOS, cloud, account, payment, generic terminal, SSH, multi-agent, or unverified approval-routing claims.

## Required Shot List

| File | Screen | Required visible state | Verification before capture |
| --- | --- | --- | --- |
| `iphone-dashboard-paired.png` | Dashboard | Paired Mac, online/sync state, Pinned or All Chats visible | Launch iPhone simulator/device with a paired local Handrail CLI and confirm the app renders current chat rows without tab-bar overlap. |
| `iphone-chats-list.png` | Chats | Online paired Mac, sync row, chat list with human-readable Codex chat titles | Refresh the chat list and confirm project names/titles do not expose raw slugs or raw `codex:` identifiers. |
| `iphone-chat-detail.png` | Chat Detail | Readable Codex chat content with user/Codex turns | Open a real Codex Desktop chat and confirm detail content is not stale global error text or raw unreadable process output. |
| `iphone-new-chat.png` | New Chat | Prompt composer, project choice, work mode, access/model controls | Open New Chat from Dashboard or Chats and confirm no stale global error is shown before user action. |

## Deferred Shot

| File | Screen | Required visible state | Release gate before capture |
| --- | --- | --- | --- |
| `iphone-approval.png` | Approval request | Approval summary, changed files, Approve and Deny controls | Defer until #2 has first-class Desktop approval request IDs and #29 can create a live started chat. Do not fabricate approval state for App Store screenshots. |

## Capture Contract

1. Use an App Store-accepted iPhone 6.9-inch screenshot class simulator or physical device.
2. Record the simulator/device name, OS version, app commit, local CLI command, and screenshot paths in the PM or QA report.
3. Keep final screenshots under `store-assets/screenshots/iphone/`.
4. Close GitHub issue #28 only after the required v1 screenshots exist and `store-assets/metadata.txt` has final support, marketing decision, privacy policy URL, and no unverified approval-routing claims.
