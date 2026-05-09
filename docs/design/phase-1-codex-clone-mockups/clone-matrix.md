# Phase 1 Clone Matrix

Status meanings:

- `MOCKUP READY`: iPhone mockup exists in `index.html`.
- `REFERENCE BLOCKED`: Codex Desktop reference screenshot is required, but capture is blocked in this session. As of the 2026-05-08 22:20 EDT completion audit, `references/` contains only `BLOCKED.md`, all eleven required desktop PNGs are absent, `reference-comparison-review.md` is absent, and Spotlight exact-name search found no matching required desktop PNGs. A bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors and found no required `desktop-*.png` files. A fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.
- `SIMULATOR CAPTURED`: iPhone simulator evidence exists in `test-artifacts/phase-1-codex-clone-20260508/`.
- `SIMULATOR WEAK`: Simulator evidence exists, but the required state is not fully visible.
- `SIMULATOR WAIVED`: A named and dated waiver accepts existing simulator evidence for a state that cannot be captured in this environment.
- `NO DESKTOP EQUIVALENT`: Handrail-only system path. It must stay behind Settings or overflow and use neutral Codex styling.

| Path | Mockup ID | Desktop Reference | Primary Labels | Menu / Action Order | iPhone Deviation | QC Status |
| --- | --- | --- | --- | --- | --- | --- |
| Unpaired first launch | `unpaired-first-launch` | No desktop equivalent | `Codex`, `Connect to Codex on your Mac`, `Scan Pairing QR`, `Enter URL manually` | Scan Pairing QR, Enter URL manually, Help | Handrail pairing is local-first iPhone-only setup | MOCKUP READY, SIMULATOR CAPTURED, NO DESKTOP EQUIVALENT |
| QR pairing | `qr-pairing` | No desktop equivalent | `Pair Handrail`, `Scan the QR code printed by handrail pair.` | Cancel, camera scan | Native camera surface is required | MOCKUP READY, SIMULATOR CAPTURED, NO DESKTOP EQUIVALENT |
| Pairing success | `pairing-success` | No desktop equivalent | `Connected`, `MacBook Pro`, `Continue` | Continue | Local pairing confirmation only | MOCKUP READY, SIMULATOR CAPTURED, NO DESKTOP EQUIVALENT |
| Paired chat list | `paired-chat-list` | `desktop-chat-list` | `Codex`, `New chat`, `Search`, `Pinned`, `Recent` | Search, New chat, More | One-column iPhone stack instead of desktop sidebar plus detail | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Empty chat list | `empty-chat-list` | `desktop-chat-list` | `Codex`, `New chat`, `No chats yet` | New chat, More | Empty state is compact and not a dashboard | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Search chats | `search-chats` | `desktop-search` | `Search`, `Cancel`, `Search chats` | Query field, Cancel, results | Search occupies full iPhone screen | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| New chat | `new-chat` | `desktop-new-chat` | `New chat`, `Project`, existing project names, `No project`, `Branch`, `Start chat` | Project list by name, Branch, Prompt, Start chat, Cancel | Project choices show names only, never file paths | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Active chat thread | `active-chat-thread` | `desktop-active-thread` | Back, title, path, `Stop`, `Ask Codex` | Back, More, Stop, composer | User messages align right in bubbles; assistant messages align left in bubbles | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Completed chat thread | `completed-chat-thread` | `desktop-active-thread` | Back, title, path, `Ask Codex` | Back, More, composer | User messages align right in bubbles; assistant messages align left in bubbles | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Focused composer | `focused-composer` | `desktop-active-thread` | `Ask Codex`, send icon | Text input, send | Keyboard visibility waived in `focused-composer-keyboard-waiver.md` | MOCKUP READY, SIMULATOR WAIVED, REFERENCE BLOCKED |
| Sending input | `sending-input` | `desktop-running-thinking` | `Sending...`, `Stop` | Stop | Inline pending status beside composer | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Codex running/thinking | `running-thinking` | `desktop-running-thinking` | `Thinking`, `Stop` | Stop, disclosure | Inline transcript artifact only | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Stop Codex | `stop-codex` | `desktop-running-thinking` | `Stop Codex?`, `Cancel`, `Stop` | Cancel, Stop | iPhone confirmation sheet is allowed before destructive stop | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Approval required | `approval-required` | `desktop-approval-required` | `Approval required`, `Deny`, `Approve`, `Diff` | Diff, Deny, Approve | Compact inline approval block | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Approve flow | `approve-flow` | `desktop-approval-required` | `Approve`, `Approval sent` | Approve | Inline result after action | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Deny flow | `deny-flow` | `desktop-approval-required` | `Deny`, `Reason`, `Send denial` | Reason, Send denial, Cancel | Denial reason uses a compact sheet | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Approval result | `approval-result` | `desktop-approval-result` | `Approved`, `Denied` | None | Inline muted result | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| File artifact | `file-artifact` | `desktop-file-artifact` | `Files`, file paths | Open file rows | Inline file list | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Diff artifact | `diff-artifact` | `desktop-diff-artifact` | `Diff`, file path | Collapse, expand | Monospace diff block in transcript | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Error state | `error-state` | `desktop-error` | `Error`, `Retry`, `Copy details` | Retry, Copy details | Compact inline error artifact | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Disconnected Mac | `disconnected-mac` | `desktop-chat-list` | `Disconnected`, `Reconnect`, `Settings` | Reconnect, Settings | Local connection banner above chat list | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Reconnecting | `reconnecting` | `desktop-chat-list` | `Reconnecting...` | None | Compact banner with spinner | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Settings | `settings` | `desktop-settings-menu` | `Settings`, `Pairing`, `Local network`, `Automations`, `Alerts` | Pairing, Local network, Automations, Alerts | Handrail-only management behind Settings | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Pairing management | `pairing-management` | No desktop equivalent | `Pairing`, `MacBook Pro`, `Reset Pairing`, `Scan QR` | Scan QR, Reset Pairing | Handrail-only local pairing management | MOCKUP READY, SIMULATOR CAPTURED, NO DESKTOP EQUIVALENT |
| Local network/help | `local-network-help` | No desktop equivalent | `Local network`, `handrail pair`, `handrail serve` | Copy command, Done | Handrail-only help route | MOCKUP READY, SIMULATOR CAPTURED, NO DESKTOP EQUIVALENT |
| Automations | `automations` | `desktop-settings-menu` | `Automations`, `No automations` | New automation disabled unless existing route remains | Secondary management only | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
| Alerts / Attention | `alerts-attention` | `desktop-settings-menu` | `Alerts`, `Approval required`, `Failed` | Open chat, Mark as read | Secondary list only, not primary tab | MOCKUP READY, SIMULATOR CAPTURED, REFERENCE BLOCKED |
