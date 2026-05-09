# Handrail iPhone Codex Desktop Clone Implementation Handoff

## Goal

Rebuild the Handrail iPhone UI as a close mobile clone of Codex Desktop.

The implementation must replace the current Handrail dashboard/tab/card visual language with the Codex Desktop chat experience adapted to iPhone. The first screen after pairing is the Codex chat list. The main flow is chat list -> chat thread -> composer, with secondary Handrail management surfaces behind Settings or overflow menus.

This is a UI implementation task, not a product expansion. Handrail remains a free, local-first iOS remote control for Codex Desktop chats on the user's Mac.

## Source Artifacts

Use these files as the implementation contract:

- Mockup board: `docs/design/phase-1-codex-clone-mockups/index.html`
- Clone matrix: `docs/design/phase-1-codex-clone-mockups/clone-matrix.md`
- QC checklist: `docs/design/phase-1-codex-clone-mockups/qc-checklist.md`
- Desktop reference manifest: `docs/design/phase-1-codex-clone-mockups/reference-capture-manifest.md`

The current mockups are not final sign-off proof. Desktop reference screenshots are still required because Computer Use could not access `com.openai.codex` during mockup creation.

## Current Implementation Status

The SwiftUI implementation is substantially covered by simulator evidence, but this handoff is not complete.

As of the 2026-05-08 22:20 EDT completion audit, `docs/design/phase-1-codex-clone-mockups/references/` contains only `BLOCKED.md`; all eleven required `desktop-*.png` files are absent, `reference-comparison-review.md` is absent, and `check-desktop-references.sh` exits nonzero on the missing desktop reference set. Searches also found no matching required desktop PNGs: Spotlight exact-name search returned no matches; a bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors; and a fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.

The latest prompt-to-artifact completion audit is recorded in `docs/design/phase-1-codex-clone-mockups/completion-audit-20260508.md` under `Completion Audit Against Objective 2026-05-08 22:20 EDT`. It maps the goal, source artifacts, non-negotiable UI requirements, required screen coverage, validation gates, and acceptance definition to concrete evidence. Its completion decision is `not complete` because the desktop reference PNG captures and dependent comparison artifacts are missing.

Current evidence and blockers are recorded in:

- `docs/design/phase-1-codex-clone-mockups/README.md`
- `docs/design/phase-1-codex-clone-mockups/index.html`
- `docs/design/phase-1-codex-clone-mockups/clone-matrix.md`
- `docs/design/phase-1-codex-clone-mockups/qc-checklist.md`
- `docs/design/phase-1-codex-clone-mockups/reference-capture-manifest.md`
- `docs/design/phase-1-codex-clone-mockups/implementation-audit-20260508.md`
- `docs/design/phase-1-codex-clone-mockups/completion-audit-20260508.md`
- `docs/design/phase-1-codex-clone-mockups/end-of-day-summary-20260508.md`
- `docs/design/phase-1-codex-clone-mockups/references/BLOCKED.md`
- `docs/design/phase-1-codex-clone-mockups/desktop-reference-capture-runbook.md`
- `docs/design/phase-1-codex-clone-mockups/check-desktop-references.sh`
- `docs/design/phase-1-codex-clone-mockups/reference-comparison-map.md`
- `docs/design/phase-1-codex-clone-mockups/verify-evidence.sh`
- `docs/design/phase-1-codex-clone-mockups/focused-composer-keyboard-waiver.template.md`
- `docs/design/phase-1-codex-clone-mockups/focused-composer-keyboard-waiver.md`
- `docs/design/phase-1-codex-clone-mockups/reference-comparison-review.template.md`
- `test-artifacts/phase-1-codex-clone-20260508/`

Do not mark this handoff complete until `verify-evidence.sh` exits cleanly. At minimum, that requires the required `references/desktop-*.png` screenshots, completed comparison and QC review, updated clone-matrix statuses, and updated reference-manifest statuses. The focused-composer keyboard gate is covered by `focused-composer-keyboard-waiver.md`.

Current verifier coverage:

- Required Codex Desktop reference screenshots as valid PNG files with readable nonzero dimensions.
- References directory contains no extra `desktop-*.png` files outside the required desktop reference list.
- Desktop reference manifest row list matches the verifier's required desktop reference list.
- Desktop reference manifest, comparison map, and review template all cover the same required desktop screenshot set, and the comparison map plus review template list the same mapped simulator evidence set.
- Desktop reference manifest table marks every required desktop reference row with `Captured` in the Status column.
- Required iPhone simulator screenshots as valid 368x800 JPEG files.
- Clone matrix row coverage, including documented simulator evidence aliases for active chat thread and file artifact rows.
- Verifier clone-matrix row list matches the actual `clone-matrix.md` mockup IDs.
- Mockup-board coverage for every clone-matrix mockup ID in `index.html`.
- Comparison-map coverage for every clone-matrix row that has a desktop reference.
- Focused-composer software-keyboard screenshot as a valid 368x800 JPEG or explicit waiver with nonblank reviewer name/date, concrete reason content, and no template placeholder or template instruction text.
- Completed desktop-reference comparison review and its template with nonblank reviewer/date, concrete findings content, concrete required-corrections content, no blank template bullets or template instruction text, `Decision: PASS.`, `QC hard rejection review: PASS.`, and the comparison map, mockup board, clone matrix, QC checklist, every required desktop reference, and every simulator evidence input listed as applicable.
- Static banned-string rejection checks.
- Case-insensitive product-expansion rejection checks across iOS and CLI code for cloud relay/storage, hosted execution, login, payment, generic terminal/SSH, multi-agent, non-Codex agents, and direct file editing.
- Phone root contract: `PhoneRootView` enters `ChatsView` through `NavigationStack(path:)` and `RootView.swift` contains no `TabView` or `DashboardView`.
- New chat project selector contract: includes `No project`, prepends it when server projects omit it, and displays project names in the menu.
- Clone matrix completion: every table row has `PASS` in the QC Status cell and no `REFERENCE BLOCKED` or `SIMULATOR WEAK` rows remain.
- LF line endings for generated Markdown, HTML, and shell artifacts in this handoff package, including completed waiver or review artifacts if present.
- `verify-evidence.sh` is executable.
- `check-desktop-references.sh` is executable, has LF line endings, directly validates the eleven required desktop PNG files after manual capture, and its required reference list matches the main verifier's required desktop-reference list.
- `desktop-reference-capture-runbook.md` names every required `desktop-*.png` reference file.
- `README.md` names both the post-capture desktop-reference validator and the final acceptance verifier.
- `references/BLOCKED.md` names every required `desktop-*.png` reference file, the post-capture desktop-reference validator, and the final acceptance verifier.
- `reference-capture-manifest.md` names the post-capture desktop-reference validator before any row moves from `Blocked` to `Captured`.
- `implementation-handoff.md` names both the post-capture desktop-reference validator and the blocker note in `references/`.
- Recorded iPhone simulator build/run log with `BUILD SUCCEEDED`.
- Recorded iPhone simulator test log with 52 passed tests and `TEST EXECUTE SUCCEEDED`.

Current verifier failure:

```text
missing references/desktop-chat-list.png
missing references/desktop-new-chat.png
missing references/desktop-active-thread.png
missing references/desktop-running-thinking.png
missing references/desktop-approval-required.png
missing references/desktop-approval-result.png
missing references/desktop-file-artifact.png
missing references/desktop-diff-artifact.png
missing references/desktop-error.png
missing references/desktop-search.png
missing references/desktop-settings-menu.png
missing reference comparison review
clone matrix still has REFERENCE BLOCKED or SIMULATOR WEAK rows
clone matrix has rows without PASS in QC Status
reference manifest row not marked Captured for desktop-chat-list
reference manifest row not marked Captured for desktop-new-chat
reference manifest row not marked Captured for desktop-active-thread
reference manifest row not marked Captured for desktop-running-thinking
reference manifest row not marked Captured for desktop-approval-required
reference manifest row not marked Captured for desktop-approval-result
reference manifest row not marked Captured for desktop-file-artifact
reference manifest row not marked Captured for desktop-diff-artifact
reference manifest row not marked Captured for desktop-error
reference manifest row not marked Captured for desktop-search
reference manifest row not marked Captured for desktop-settings-menu
```

## Non-Negotiable Requirements

- No purple theme, purple tint, purple selected state, purple send button, or purple decorative surface in the primary iPhone UI.
- No dashboard-first screen after pairing.
- No bottom tab bar in the primary chat/list/thread flow.
- No `Round 1`, `Round 2`, parser/debug labels, or transcript implementation terminology in user-facing UI.
- No giant transcript cards, dashboard cards, metric panels, shortcut grids, or oversized running status slabs.
- New chat project selection must list existing projects by name and include `No project`. It must not display filesystem paths as the visible project choice.
- Chat threads must use Codex Desktop message geometry: user messages in right-side bubbles, assistant messages in left-side bubbles.
- All primary labels, menus, and action ordering must match Codex Desktop unless a concrete iPhone constraint is documented.
- Handrail-specific pairing, local network, automations, alerts, and diagnostics must remain secondary management surfaces, not the main product surface.

## Implementation Scope

Implement the iPhone UI only. iPad may be corrected for shared components if required by compilation, but iPad redesign is not part of this handoff.

Expected high-level changes:

- Replace the iPhone `TabView` shell in `RootView.swift` with a chat-first `NavigationStack`.
- Replace the current dashboard/chat list entry surface with a Codex-style chat list.
- Rebuild `ChatDetailView.swift` around a compact header, desktop-style transcript bubbles, inline artifacts, and fixed bottom composer.
- Update `ChatTranscriptView.swift` so user/assistant turns render with the required desktop geometry and no round labels.
- Keep existing data/state/protocol contracts unless a narrow compiler-required adjustment is unavoidable.

Do not change networking, pairing protocol, cloud behavior, storage model, agent support, payment/account state, or file editing capabilities.

## Required Screen Coverage

Every path in `clone-matrix.md` must be implemented or intentionally kept behind Settings/overflow as marked there:

- Unpaired first launch
- QR pairing
- Pairing success
- Paired chat list
- Empty chat list
- Search chats
- New chat
- Active chat thread
- Completed chat thread
- Focused composer with keyboard
- Sending input
- Codex running/thinking
- Stop Codex
- Approval required
- Approve flow
- Deny flow
- Approval result
- File artifact
- Diff artifact
- Error state
- Disconnected Mac
- Reconnecting
- Settings
- Pairing management
- Local network/help instructions
- Automations if still reachable
- Alerts/attention if still reachable

## Validation Gates

Before reporting implementation complete:

1. Capture Codex Desktop reference screenshots listed in `reference-capture-manifest.md`.
2. Build and run Handrail on an iPhone simulator.
3. Capture simulator screenshots for every implemented path in `clone-matrix.md`.
4. Compare simulator screenshots against the desktop references and mockups.
5. Run static checks for banned UI drift:
   - `.purple`
   - `Round `
   - `Dashboard` in the primary iPhone flow
   - `TabView` in the primary iPhone shell
   - `Files to change`
   - `Ready for follow-up`
   - `Send input` unless desktop reference proves that exact label
6. Run the iOS test/build command appropriate for the current simulator, then launch the app and verify the visible UI in simulator.

Simulator validation is mandatory. Build success alone is not sufficient.

## Acceptance Definition

The work is complete only when:

- The iPhone app opens to the Codex-style chat list after pairing.
- The chat thread visually matches Codex Desktop message direction, palette, hierarchy, and composer behavior.
- New chat project selection lists project names plus `No project`, not paths.
- Every path in the clone matrix is implemented or explicitly documented as secondary/unreachable.
- Desktop reference screenshots and simulator screenshots exist for QC.
- The QC checklist passes with no hard rejection items.

Any single hard rejection item means the implementation is not complete.
