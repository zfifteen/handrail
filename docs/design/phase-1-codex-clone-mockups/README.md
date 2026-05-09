# Phase 1 Codex Desktop Clone Mockup Pack

This package defines the Phase 1 mockups and implementation evidence for the Handrail iPhone redesign. The goal is a complete screen-by-screen Codex Desktop clone adapted to iPhone, with simulator evidence and desktop-reference QC before sign-off.

## Artifacts

- `index.html`: visual mockup board for every iPhone path in Phase 1.
- `clone-matrix.md`: path inventory, desktop reference mapping, labels, actions, deviations, and QC status.
- `qc-checklist.md`: rejection gates for design and clone QC.
- `reference-capture-manifest.md`: required Codex Desktop reference screenshots and capture status.
- `desktop-reference-capture-runbook.md`: exact manual capture and post-capture verification steps.
- `check-desktop-references.sh`: narrow post-capture validator for the eleven required desktop PNG files.
- `reference-comparison-map.md`: desktop-reference to simulator-evidence comparison map.
- `reference-comparison-review.template.md`: template for recording the required desktop-to-simulator review.
- `verify-evidence.sh`: executable deterministic acceptance verifier for references, screenshots, reviews, matrix status, source invariants, line endings, and the recorded simulator test log.
- `focused-composer-keyboard-waiver.template.md`: template for an explicit reviewer waiver if the keyboard screenshot is not required.
- `focused-composer-keyboard-waiver.md`: accepted waiver for the visible software-keyboard screenshot, tied to `focused-composer.jpg`.
- `implementation-handoff.md`: active implementation contract, current status, verifier coverage, validation gates, and acceptance definition.
- `implementation-audit-20260508.md`: implementation evidence, simulator captures, and unresolved gates.
- `completion-audit-20260508.md`: prompt-to-artifact completion audit against `implementation-handoff.md`.
- `end-of-day-summary-20260508.md`: clean stop point, accomplishments, remaining work, failed paths, and next-session first action.
- `references/BLOCKED.md`: capture-blocker evidence and exact unblock contract for desktop references.

## Current Status

All required iPhone paths have a mockup in `index.html`. The SwiftUI implementation is substantially covered by simulator screenshots in `test-artifacts/phase-1-codex-clone-20260508/`.

Desktop reference capture is blocked because this session cannot capture `com.openai.codex` or the display. As of the 2026-05-08 22:20 EDT completion audit, the reference directory contains only `references/BLOCKED.md`, all eleven required `desktop-*.png` files are absent, `reference-comparison-review.md` is absent, and `check-desktop-references.sh` exits nonzero on the missing desktop reference set. Searches also found no matching required desktop PNGs: Spotlight exact-name search returned no matches; a bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors; and a fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. Recent screenshots in common manual capture locations were checked and do not satisfy the manifest; the desktop-sized candidates show Comet/X, cropped text, or ChatGPT connector UI, not Codex Desktop. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.

The latest prompt-to-artifact audit is in `completion-audit-20260508.md` under `Completion Audit Against Objective 2026-05-08 22:20 EDT`. Its completion decision is `not complete` because the desktop reference PNG captures and dependent comparison artifacts are missing.

The focused composer visible-keyboard screenshot is waived in `focused-composer-keyboard-waiver.md`. The accepted simulator evidence is `test-artifacts/phase-1-codex-clone-20260508/focused-composer.jpg`, which captures focus, typed input, and enabled Send.

Phase 1 becomes sign-off ready only after the desktop reference captures are added as valid PNG files and `check-desktop-references.sh` exits cleanly. Then each implemented screen must be compared against the desktop references and mockups with a named and dated `Decision: PASS.` and `QC hard rejection review: PASS.` review that lists the mockup board, clone matrix, every desktop input, every simulator input, and exactly the mapped desktop-reference-to-simulator pairs from `reference-comparison-map.md`, includes concrete findings and required-corrections content, has `PASS` in every comparison-result cell, every template placeholder and template instruction is removed, every `clone-matrix.md` table row has `PASS` in the QC Status cell, every required reference in `reference-capture-manifest.md` is marked `Captured`, and `verify-evidence.sh` exits cleanly.

## Open The Mockup Board

Open:

`docs/design/phase-1-codex-clone-mockups/index.html`

The board uses a neutral Codex-style dark palette and intentionally excludes purple, dashboard-first layout, bottom tabs, parser labels, and card-heavy transcript treatment.
