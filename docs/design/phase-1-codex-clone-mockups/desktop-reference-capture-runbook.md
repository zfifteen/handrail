# Desktop Reference Capture Runbook

Use this runbook to unblock Phase 1 when Codex Desktop can be captured from the user's Mac.

## Output Directory

Save every screenshot in:

```text
/Users/velocityworks/IdeaProjects/handrail/docs/design/phase-1-codex-clone-mockups/references/
```

Do not save screenshots in `test-artifacts/` for this gate. Do not substitute older artifacts.

## Required Files

Capture the current Codex Desktop app into these exact files:

| File | Required State |
| --- | --- |
| `desktop-chat-list.png` | Chat/session list or sidebar |
| `desktop-new-chat.png` | New chat surface |
| `desktop-active-thread.png` | Active thread with transcript and composer |
| `desktop-running-thinking.png` | Running or thinking state |
| `desktop-approval-required.png` | Approval required state |
| `desktop-approval-result.png` | Post-approval or post-denial desktop state showing the result of the approval decision |
| `desktop-file-artifact.png` | File references in transcript |
| `desktop-diff-artifact.png` | Diff view in transcript |
| `desktop-error.png` | Error state |
| `desktop-search.png` | Search state |
| `desktop-settings-menu.png` | Settings and menu surfaces |

Current state as of 2026-05-08 21:53 EDT: none of these PNG files exist in `references/`; that directory contains only `BLOCKED.md`. Exact-name filesystem search found no required `desktop-*.png` files under the project tree, Desktop, Downloads, Pictures, or `/private/tmp`; Spotlight exact-name search also returned no matches. A broader exact-name `find /Users/velocityworks ...` search produced no matches before ending with `find: fts_read: Interrupted system call`, so that broader search is not exhaustive evidence. A bounded exact-name `find /Users/velocityworks ...` search that pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers` exited cleanly with no errors and found no required `desktop-*.png` files. A fresh exact-name search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`. A fresh direct directory inspection confirmed all eleven required `desktop-*.png` files are still absent, and `reference-comparison-review.md` is still absent. A shell GUI probe still cannot supply the screenshots: System Events process enumeration fails with error `-10827`, and the display profiler reports no attached display detail usable for capture.

## PNG Acceptance Rules

Each desktop reference must satisfy all of these conditions before any matrix, manifest, or review status is updated:

- The file is a current Codex Desktop screenshot from the user's visible Mac app.
- The file is stored directly in `docs/design/phase-1-codex-clone-mockups/references/`.
- The file name exactly matches one required `desktop-*.png` name above.
- The file is PNG image data with readable nonzero dimensions.
- The directory contains no extra `desktop-*.png` files beyond the required list.

`desktop-approval-result.png` is required. If Codex Desktop does not show a separate approval-result component, capture the desktop thread state immediately after an approve or deny action produces its visible result, then document that observation in `reference-comparison-review.md`.

After saving the screenshots, run this file-only check from the repository root:

```sh
docs/design/phase-1-codex-clone-mockups/check-desktop-references.sh
```

Do not mark a reference `Captured` if this command reports a missing file, a non-PNG file, unreadable dimensions, or an unexpected extra `desktop-*.png` file.

## Manual Capture Procedure

Use the user's visible Codex Desktop app. For each required state:

1. Put Codex Desktop in the required state listed above.
2. Capture only the Codex Desktop window or relevant Codex Desktop region.
3. Save the screenshot to the exact required file path under `docs/design/phase-1-codex-clone-mockups/references/`.
4. Keep the file as PNG.

The native macOS screenshot UI is acceptable for this blocked gate:

```text
Command-Shift-5
```

Set the save location to:

```text
/Users/velocityworks/IdeaProjects/handrail/docs/design/phase-1-codex-clone-mockups/references/
```

Rename each capture to the exact required file name before running the verifier. Do not update `clone-matrix.md` or `reference-capture-manifest.md` until the PNG files exist.

## After Capture

Run the verifier once after adding the desktop PNGs to identify the remaining gates:

```sh
docs/design/phase-1-codex-clone-mockups/verify-evidence.sh
```

At this point a nonzero exit is expected if the comparison review, clone matrix statuses, or reference manifest statuses are still incomplete. Use the remaining verifier output as the work list.

The focused composer visible-keyboard requirement is already covered by:

```text
docs/design/phase-1-codex-clone-mockups/focused-composer-keyboard-waiver.md
```

That waiver is tied to:

```text
test-artifacts/phase-1-codex-clone-20260508/focused-composer.jpg
```

Do not recreate that waiver unless the review decision changes.

After the desktop references exist, use `reference-comparison-map.md` for the desktop-reference comparison pass. Record the result in:

```text
docs/design/phase-1-codex-clone-mockups/reference-comparison-review.md
```

Use `reference-comparison-review.template.md` as the starting point. The verifier requires the completed review artifact before Phase 1 can pass, and the completed review must contain this exact decision line:

```text
Decision: PASS.
```

It must also contain this exact QC line after reviewing `qc-checklist.md` against the implemented iPhone evidence:

```text
QC hard rejection review: PASS.
```

The completed review must also include a nonblank reviewer and date, the mockup board, clone matrix, every required desktop reference plus simulator evidence input, concrete findings content, required corrections content, and no template instruction text.

After the review passes, update `clone-matrix.md` so no table row still contains:

```text
REFERENCE BLOCKED
```

Do not remove status definitions from the top of the file; the verifier checks table rows only.

Every clone-matrix table row must also include `PASS` in its QC Status cell.

Update `reference-capture-manifest.md` so every required desktop reference row has `Captured` in the Status column.

Run the verifier again after updating the matrix and manifest:

```sh
docs/design/phase-1-codex-clone-mockups/verify-evidence.sh
```

The final verifier run must exit `0`. Any nonzero exit means the handoff is still not complete.
