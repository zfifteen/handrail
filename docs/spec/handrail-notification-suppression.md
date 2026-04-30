# Handrail Notification Suppression

This document records Handrail's current notification flow and the expected active-chat suppression contract.

Observed Desktop build:

- App version: `26.422.71525`
- Build number: `2210`
- Bundle id: `com.openai.codex`

Related issue:

- [GitHub issue #10: Notification is shown for the chat currently open in iOS](https://github.com/zfifteen/handrail/issues/10)

Related source:

- `cli/src/server.ts`
- `cli/src/notifications.ts`
- `ios/Handrail/Handrail/Stores/HandrailStore.swift`
- `ios/Handrail/Handrail/Utilities/NotificationCoordinator.swift`

## Expected Contract

Handrail should notify only when the receiving surface is not currently viewing that conversation.

The active-chat invariant is:

```text
If iOS is currently viewing chat X, iOS should not show a notification for chat X.
```

## CLI Push Flow

Observed:

- `startServer` polls visible chats every 5 seconds by default.
- Each poll calls `NotificationDispatcher.notifyVisibleChats`.
- `notificationEventForChat` creates events for:
  - `completed`
  - `failed`
  - `approval_required`
  - `input_required`
- Event ids are based on chat id, kind, timestamp, and an optional input marker hash.
- Sent event ids are persisted in `HandrailState.sentNotificationEventIds`.
- The CLI does not currently receive or use the iOS active chat id in the notification decision.

Inferred:

- CLI push suppression can prevent APNs delivery only if iOS sends its current visible chat id to the server.

Unknown:

- Whether the Desktop app has its own notification suppression state that Handrail should mirror.

## iOS Local Notification Flow

Observed:

- `HandrailStore.handleMessage` handles WebSocket messages.
- `approval_required` inserts an in-app notification and calls `notifyApproval`.
- `chat_event` with `chat_completed` calls `notifyChatCompleted`.
- `chat_event` with `chat_failed` calls `notifyChatFailed`.
- Output text containing `input required` calls `notifyInputRequired`.
- `NotificationCoordinator.willPresent` decides whether a notification is presented while the app is foregrounded.

Inferred:

- The regression can happen on iOS even if APNs is correct, because local foreground notification calls also need active-chat suppression.

Unknown:

- Whether all notification sources carry the same normalized `chatId` form.
- Whether the app currently stores the active chat id in the notification coordinator or only in SwiftUI navigation state.

## Suppression Points

Possible suppression layers:

1. CLI APNs sender suppresses events for the active iOS chat.
2. iOS store suppresses local notification creation for the active chat.
3. iOS notification delegate suppresses foreground presentation for the active chat.

The minimum deterministic fix should choose one authoritative active-chat check and apply it consistently before presenting a user-visible notification.

## Handrail Implication

Notification suppression is separate from Desktop-visible sync. A chat can fail to repaint on Desktop while iOS notification suppression is still correct, and the reverse can also happen.

The invariant is:

```text
Notification eligibility depends on receiver attention, not on chat status alone.
```

