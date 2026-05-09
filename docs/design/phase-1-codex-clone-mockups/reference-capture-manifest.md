# Codex Desktop Reference Capture Manifest

Desktop reference capture is blocked in this session. Computer Use cannot access `com.openai.codex`, shell display capture fails, shell GUI process enumeration fails, local Codex app-support data does not contain usable screenshots, and recent screenshots in common manual capture locations do not satisfy this manifest. The desktop-sized candidates were visually inspected and show Comet/X, cropped text, or ChatGPT connector UI, not Codex Desktop. These references are required before Phase 1 can be marked accepted.

| Reference ID | Required Codex Desktop State | Status | Notes |
| --- | --- | --- | --- |
| desktop-chat-list | Chat/session list or sidebar | Blocked | Required for paired chat list, empty chat list, search, disconnected, reconnecting |
| desktop-new-chat | New chat surface | Blocked | Required for new chat |
| desktop-active-thread | Active thread with transcript and composer | Blocked | Required for active thread, completed thread, focused composer |
| desktop-running-thinking | Running or thinking state | Blocked | Required for sending input, running/thinking, stop Codex |
| desktop-approval-required | Approval required state | Blocked | Required for approval required, approve, deny |
| desktop-approval-result | Post-approval or post-denial desktop state showing the result of the approval decision | Blocked | Required for approval result comparison |
| desktop-file-artifact | File references in transcript | Blocked | Required for file artifact |
| desktop-diff-artifact | Diff view in transcript | Blocked | Required for diff artifact |
| desktop-error | Error state | Blocked | Required for error state |
| desktop-search | Search state | Blocked | Required for search chats |
| desktop-settings-menu | Settings and menu surfaces | Blocked | Required for settings, pairing management, local network help, automations, alerts or attention |

## Capture Rules

- Use the current Codex Desktop app visible on the user's Mac.
- Store screenshots in `docs/design/phase-1-codex-clone-mockups/references/`.
- File names must match the reference IDs above with `.png`.
- Do not substitute Happy, old Handrail, or generic iOS screenshots for Codex Desktop references.
- If Codex Desktop has no equivalent for a Handrail-only system path, record `No desktop equivalent` in the clone matrix and keep the iPhone screen behind Settings or an overflow menu.

## Current Blocker

Capture is blocked in this session. Evidence is recorded in `references/BLOCKED.md`, including the failed app, display, shell GUI, app-support, Spotlight, exact-name filesystem, common-screenshot-location, and visual screenshot-candidate checks. Manual capture steps are recorded in `desktop-reference-capture-runbook.md`.

As of the 2026-05-08 22:20 EDT completion audit, `references/` contains only `BLOCKED.md`; all eleven required `desktop-*.png` files are absent, `reference-comparison-review.md` is absent, and Spotlight exact-name search found no matching required desktop PNGs. A bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors and found no required `desktop-*.png` files. A fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.

After capture, run `docs/design/phase-1-codex-clone-mockups/check-desktop-references.sh` before changing any Status cell from `Blocked` to `Captured`.
