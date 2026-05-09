# Phase 1 Mockup QC Checklist

## Hard Rejection Gates

Reject a mockup immediately if it shows any of the following in the primary iPhone chat flow:

- Purple theme, purple tint, purple send button, purple selected state, or purple decorative surface.
- Dashboard-first opening screen after pairing.
- Bottom tab bar in chat list, active thread, composer, approval, file, diff, or search flow.
- `Round 1`, `Round 2`, parser/debug labels, or transcript implementation terminology.
- Giant transcript cards, dashboard cards, metric panels, or shortcut grids.
- Large green `Codex is working` slab.
- Full-width form-like send button.
- Invented Handrail chat labels where Codex Desktop has an equivalent label.
- Handrail system surfaces taking over the primary Codex chat surface.
- New chat project choices showing file paths instead of existing project names plus `No project`.
- Chat thread geometry that does not place user messages in right-side bubbles and assistant messages in left-side bubbles.

## Required Review Order

1. Text: labels must match Codex Desktop or document an iPhone-only constraint.
2. Shape: hierarchy must read as Codex Desktop adapted to iPhone.
3. Color: neutral dark Codex palette, no purple.
4. Density: compact transcript/list treatment, no dashboard spacing.
5. Navigation: chat-first stack, secondary Handrail paths behind menu/settings.

## Phase 1 Acceptance

Every row in `clone-matrix.md` must reach `PASS`.

Current implementation status:

- Local hard-rejection static checks pass for `.purple`, `Color.purple`, `TabView`, `Round `, `Files to change`, `Ready for follow-up`, `Send input`, and `Codex is working`.
- The primary phone route enters `ChatsView` directly. Remaining `Dashboard` references are legacy dashboard, iPad workspace, and tests.
- Simulator evidence exists for every clone-matrix row. The visible software keyboard portion of focused composer is explicitly waived in `focused-composer-keyboard-waiver.md`.
- Focused composer evidence is accepted for Phase 1 through the waiver: `focused-composer.jpg` captures focus, typed input, and enabled Send, while the simulator did not expose the visible software keyboard in the captured state.
- Desktop reference comparison is blocked because the required `references/desktop-*.png` files do not exist. As of the 2026-05-08 21:53 EDT inspection, `references/` contains only `BLOCKED.md`, all eleven required desktop PNGs are absent, `reference-comparison-review.md` is absent, and Spotlight exact-name search found no matching required desktop PNGs. A bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors and found no required `desktop-*.png` files. A fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.

Rows marked `REFERENCE BLOCKED` in `clone-matrix.md` must not be converted to `PASS` until a reviewer compares the iPhone simulator screenshots against the captured Codex Desktop screenshots.
