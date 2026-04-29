# Handrail UI Paths

Captured from the iPhone simulator and cross-checked against the SwiftUI route map on 2026-04-28.

## Dashboard

- Open the app.
  - The app lands on `Dashboard`.
- If no machine is paired:
  - View the empty pairing state.
  - Tap `Scan Pairing QR`.
  - Scan the QR payload printed by `handrail pair`.
  - Save the paired machine and connect to the local Handrail server.
- If a machine is paired:
  - View the machine status card.
  - View sync status.
  - View the `Today` summary.
  - View `Needs attention`.
  - View `Running now`.
  - View `Pinned`.
  - View `All chats`.
- Pull down on the dashboard.
  - Refresh the Codex chat list from the server.
- Tap the sync row action.
  - If online, refresh chats.
  - If offline, reconnect.
- Tap the top-left `+` button.
  - Open `New chat`.
- Tap the top-right QR button.
  - Open the pairing scanner.
- Tap any chat row in `Needs attention`, `Running now`, `Pinned`, or `All chats`.
  - Open `Chat Detail`.
- Long-press a `Needs attention` row.
  - Show the context menu.
  - Tap `Dismiss`.

## Chats

- Open the `Chats` tab.
  - View paired machine status.
  - View sync status.
  - View `New chat`.
  - View `Active chats` when active chats exist.
  - View `Pinned`.
  - View `All chats`.
- Pull down on the chats list.
  - Refresh the Codex chat list from the server.
- Tap `New chat`.
  - Open `New chat`.
- Tap the QR button.
  - Open the pairing scanner.
- Tap a pinned chat.
  - Open `Chat Detail`.
- Tap an all-chats row.
  - Open `Chat Detail`.
- Tap the filter menu in `All chats`.
  - Switch between chronological and project grouping.
- Long-press a Codex desktop chat row.
  - View the desktop pin state.

## New Chat

- Open `New chat` from Dashboard or Chats.
- Tap `Cancel`.
  - Dismiss the sheet.
- Enter a prompt in the composer.
- Choose a project.
  - Select `No project`.
  - Select an existing desktop project.
- Choose a work mode.
  - Select `Work locally`.
  - Select `New worktree`.
- If a project is selected:
  - Choose an existing branch.
  - Enable `Create branch`.
  - Enter a new branch name.
- Choose an access preset.
  - Select `Ask when needed`.
  - Select `Full access`.
  - Select `Read only`.
- Choose a model.
- Choose a reasoning effort.
- Tap `Start`.
  - The app sends `start_chat` to the CLI.
  - The app routes to the started chat detail when the server returns the chat.
- If Mac is offline, prompt is empty, or a required branch value is missing:
  - `Start` remains disabled.
  - The footer explains the missing requirement.

## Chat Detail

- Open from Dashboard, Chats, Attention, Activity, Alerts, notification routing, or after starting a chat.
- Read chat content.
- View round separators when the transcript parser detects user/Codex turns.
- Drag upward in the transcript.
  - Reveal the jump-to-latest button.
- Tap the jump-to-latest button.
  - Scroll to the newest message.
- If changed files exist:
  - View `Files to change`.
- If approval is required:
  - View the approval summary.
  - View changed files.
  - Expand the diff disclosure.
  - Tap `Deny`.
  - Tap `Approve`.
- If the chat needs attention:
  - Tap the top-right dismiss button.
- If the chat is running and accepts live input:
  - Type in `Send input`.
  - Send input to the CLI.
- If the chat is running without live input:
  - View the read-only notice.
- If the chat is an archived Codex chat and the Mac is online:
  - Type a follow-up prompt.
  - Tap `Continue Chat`.
- If the chat is an archived Codex chat and the Mac is offline:
  - View the offline read-only notice.
- If the chat is controllable and running or waiting for approval:
  - Tap the stop button.
  - Send `stop_chat` to the CLI.
- If the server reports an error:
  - View the error banner in the chat.

## Attention

- Open the `Attention` tab.
- If no unresolved items exist:
  - View the empty state.
- Tap an attention item.
  - Open `Chat Detail`.
- Long-press an attention item.
  - Tap `Dismiss`.
- Tap `Dismiss All`.
  - Dismiss all currently visible attention items.

## Approval

- Open an approval from `Chat Detail` or notification routing.
- If an approval exists:
  - View approval title.
  - View chat title.
  - View summary.
  - View changed files.
  - View diff text.
  - Tap `Deny`.
  - Tap `Approve`.
- If no approval exists:
  - View the empty approval state.

## Activity

- Open the `Activity` tab.
- If no events exist:
  - View the empty state.
- If timeline events exist:
  - View event title, detail, and time.
- Tap an activity item with a chat id.
  - Open `Chat Detail`.
- View an activity item without a chat id.
  - It is informational only.

## Alerts

- On compact iPhone layout, open `More`, then open `Alerts`.
- If no notifications exist:
  - View the empty state.
- If notifications exist:
  - View notification title, detail, and time.
- Tap a notification with a chat id.
  - Open `Chat Detail`.
- View a notification without a chat id.
  - It is informational only.

## Settings

- On compact iPhone layout, open `More`, then open `Settings`.
- View the paired machine card.
  - Machine name.
  - Host and port.
  - Connection state.
- View pairing instructions.
  - `handrail pair`.
- Tap `Scan QR`.
  - Open the pairing scanner.
- View app version.
- View compatibility copy.
  - `Works with OpenAI Codex CLI. Not affiliated with OpenAI.`

## Pairing Scanner

- Open from Dashboard, Chats, or Settings.
- Scan a valid Handrail QR payload.
  - Save the paired machine.
  - Connect to the local server.
- Scan an invalid QR payload.
  - Show scanner error text.
- Tap `Close`.
  - Dismiss the scanner.
