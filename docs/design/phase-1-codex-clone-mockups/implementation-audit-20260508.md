# Phase 1 Codex Clone Implementation Audit

## Status

Implementation is partially complete. The core iPhone shell, chat list, chat thread geometry, composer label, project chooser, focused-composer waiver, and hard-rejection static checks are implemented and simulator-tested.

The handoff is not complete because Codex Desktop reference capture remains blocked, the desktop comparison and QC review artifact is missing, `clone-matrix.md` rows are not at `PASS`, and `reference-capture-manifest.md` rows are not marked `Captured`.

## Verified Evidence

- iPhone simulator: `iPhone 17`, iOS 26.4.
- Build and launch: `build_run_sim` succeeded. Latest log: `/Users/velocityworks/Library/Developer/XcodeBuildMCP/workspaces/handrail-146601e045e5/logs/build_run_sim_2026-05-08T20-53-16-451Z_pid56442_a912b1db.log`.
- Tests: `test_sim` passed 52 tests, 0 failed. Latest log: `/Users/velocityworks/Library/Developer/XcodeBuildMCP/workspaces/handrail-146601e045e5/logs/test_sim_2026-05-08T20-27-02-371Z_pid56442_2d382629.log`.
- Static banned-string check passed for:
  - `.purple`
  - `Color.purple`
  - `TabView`
  - `Round `
  - `Files to change`
  - `Ready for follow-up`
  - `Send input`
  - `Codex is working`
- Product-expansion scan passed for:
  - cloud relay/storage
  - hosted execution
  - login
  - payment
  - generic terminal/SSH
  - multi-agent
  - non-Codex agents
  - direct file editing

## Simulator Screenshots

Stored in `test-artifacts/phase-1-codex-clone-20260508/`:

- `unpaired-first-launch.jpg`
- `empty-unpaired-first-launch.jpg`
- `empty-chat-list.jpg`
- `paired-chat-list.jpg`
- `search-chats.jpg`
- `new-chat.jpg`
- `new-chat-project-menu.jpg`
- `approval-required.jpg`
- `approval-required-active-thread.jpg`
- `approve-flow.jpg`
- `deny-flow.jpg`
- `approval-result.jpg`
- `deny-result.jpg`
- `diff-artifact.jpg`
- `completed-chat-thread.jpg`
- `running-thinking.jpg`
- `stop-codex.jpg`
- `error-state.jpg`
- `disconnected-mac.jpg`
- `overflow-menu.jpg`
- `settings.jpg`
- `pairing-management.jpg`
- `local-network-help.jpg`
- `alerts-attention.jpg`
- `automations.jpg`
- `reconnecting.jpg`
- `qr-pairing.jpg`
- `pairing-success.jpg`
- `focused-composer.jpg`
- `sending-input.jpg`

## Implemented Requirements

- Phone root is a single chat-first `NavigationStack`.
- No bottom tab bar remains in the phone primary flow.
- The first paired screen is the Codex chat list, not a dashboard.
- `Dashboard` references remain in legacy dashboard, iPad workspace, and tests, but not in the primary phone route. `PhoneRootView` enters `ChatsView` directly.
- Handrail management surfaces are reachable through overflow navigation.
- Settings exposes secondary `Pairing` and `Local network` routes.
- Chat composer uses `Ask Codex`.
- Transcript user messages render as right-side bubbles.
- Transcript assistant messages render left-aligned.
- Approval required, approve, deny, approval result, and diff artifact states have simulator evidence.
- Completed, running/thinking, stop confirmation, and error states have simulator evidence.
- Offline reconnect action has simulator evidence. The captured transient state shows `Refreshing from Mac...`.
- QR pairing route has simulator evidence. The iOS simulator reports `No camera is available.`, so this proves the pairing sheet route and camera-unavailable state, not a real QR scan.
- Pairing success has simulator evidence with `Connected`, `MacBook Pro`, and `Continue`.
- Paired empty chat list has simulator evidence with `Codex`, `Pinned`, `Recent`, and `No chats yet`.
- Focused composer accepts typed input and enables the send button in simulator evidence.
- Focused composer visible software-keyboard capture is explicitly waived in `focused-composer-keyboard-waiver.md`, tied to `focused-composer.jpg`.
- Sending input has simulator evidence with `Sending...` and `Stop`.
- Running/thinking now uses `Thinking`, not `Codex is working`.
- `Round` labels are not rendered.
- File artifacts use `Files`, not `Files to change`.
- New chat project menu includes `No project` and existing project names.
- New chat project menu does not display filesystem paths.
- DEBUG-only `--handrail-preview-data`, `--handrail-preview-empty`, `--handrail-preview-empty-list`, `--handrail-preview-offline`, and `--handrail-preview-pairing-success` launch arguments provide deterministic simulator evidence without changing production app state.

## Unresolved Required Gates

- Codex Desktop reference screenshots from `reference-capture-manifest.md` are still pending. As of the 2026-05-08 21:53 EDT inspection, `references/` contains only `BLOCKED.md`; all eleven required `desktop-*.png` files are absent, `reference-comparison-review.md` is absent, and Spotlight exact-name search found no matching required desktop PNGs. A bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors and found no required `desktop-*.png` files. A fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`.
- Computer Use still reports that `com.openai.codex` is not allowed, so desktop capture cannot be completed from this session.
- `/Applications/Codex.app` is present and its bundle id is `com.openai.codex`; shell `screencapture` fails with `could not create image from display`, System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.
- CoreGraphics did not return Codex window metadata, and process inspection is blocked by sandbox policy.
- A targeted search under `~/Library/Application Support/Codex` found no `.png`, `.jpg`, `.jpeg`, or `.webp` files.
- Repository artifact search found `test-artifacts/codex-desktop-sync-before-2026-04-27.png`, but it is an older artifact outside the required references directory and does not satisfy the current desktop-reference manifest.
- The Desktop reference blocker is recorded in `docs/design/phase-1-codex-clone-mockups/references/BLOCKED.md`.
- A prompt-to-artifact completion audit is recorded in `docs/design/phase-1-codex-clone-mockups/completion-audit-20260508.md`.
- `docs/design/phase-1-codex-clone-mockups/clone-matrix.md` now records simulator-captured rows, reference-blocked rows, and the focused-composer keyboard waiver row.
- `docs/design/phase-1-codex-clone-mockups/reference-comparison-map.md` maps required desktop references to simulator evidence for the future QC comparison pass.
- `docs/design/phase-1-codex-clone-mockups/verify-evidence.sh` verifies required desktop reference files are valid PNGs with readable nonzero dimensions, the references directory has no extra `desktop-*.png` files outside the required list, the desktop reference manifest row list matches the verifier's required desktop reference list, the desktop reference manifest, comparison map, and review template cover the same desktop screenshot set, the comparison map and review template list the same mapped simulator evidence set, the comparison map and review template list exactly the required mapped desktop-reference-to-simulator pairs with no missing or unexpected pairs, the review template lists the comparison map, mockup board, clone matrix, and QC checklist inputs, the reference manifest marks every required desktop reference row with `Captured` in the Status column, simulator evidence files are valid 368x800 JPEGs, clone matrix row coverage, the verifier row list matches the actual `clone-matrix.md` mockup IDs, mockup-board coverage for every clone-matrix mockup ID, comparison-map coverage for every clone-matrix row that has a desktop reference, focused composer keyboard evidence is a valid 368x800 JPEG or an explicit waiver with nonblank reviewer name/date, concrete reason content, the existing `focused-composer.jpg` evidence input, and no template placeholder or template instruction text, the completed desktop-reference comparison review has nonblank reviewer/date, concrete findings content, concrete required-corrections content, no blank template bullets or blank comparison-result cells, no template instruction text, `Decision: PASS.`, `QC hard rejection review: PASS.`, the comparison map, mockup board, clone matrix, and QC checklist inputs listed, every required desktop reference input listed, every mapped simulator evidence input listed, and exactly the mapped desktop-reference-to-simulator pairs listed with no missing or unexpected pairs, static banned-string checks, case-insensitive product-expansion rejection checks across iOS and CLI code, the phone root enters `ChatsView` directly through `NavigationStack(path:)`, the new chat project selector includes and displays `No project` plus project names, every clone matrix row has `PASS` in the QC Status cell and no `REFERENCE BLOCKED` or `SIMULATOR WEAK` status, generated handoff text artifacts including the mockup board use LF line endings, completed waiver or review artifacts use LF line endings if present, the verifier script is executable, the recorded simulator build/run log has `BUILD SUCCEEDED`, and the recorded 52-test simulator log. It currently fails on the missing desktop references, missing reference comparison review, clone matrix rows not at PASS, and reference manifest rows not marked `Captured`.
- Simulator screenshots are captured for every row in `clone-matrix.md`. The focused-composer visible software-keyboard requirement is covered by `focused-composer-keyboard-waiver.md`; the simulator accepted typed input and enabled Send, but did not expose the soft keyboard in the captured state.
- Attempts to force the software keyboard through Simulator preferences are recorded in `references/BLOCKED.md`; the waiver is the accepted Phase 1 evidence for this simulator-specific capture gap.
- The QC checklist cannot pass while desktop reference comparison remains pending.

## Completion Decision

Do not mark `implementation-handoff.md` complete yet. The required reference-capture gate remains open, the desktop comparison and QC review artifact is missing, `clone-matrix.md` rows are not at `PASS`, and `reference-capture-manifest.md` rows are not marked `Captured`.
