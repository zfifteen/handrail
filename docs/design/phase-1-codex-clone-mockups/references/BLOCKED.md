# Codex Desktop Reference Capture Blocker

## Reading Note

Entries before 2026-05-08 20:26 EDT are historical snapshots and may mention the focused-composer keyboard waiver as missing. The current state is recorded in `../completion-audit-20260508.md` under `Completion Audit Against Objective 2026-05-08 22:20 EDT`: `../focused-composer-keyboard-waiver.md` exists and is accepted by `../verify-evidence.sh`; the remaining blocker is the missing Codex Desktop reference PNG set and dependent comparison artifacts.

Computer Use cannot capture the required Codex Desktop reference screenshots in this session.

Observed blocker on 2026-05-08:

```text
Computer Use is not allowed to use the app 'com.openai.codex' for safety reasons.
```

The same denial occurs when addressing the app by display name `Codex`; Computer Use resolves it to `com.openai.codex`.

Additional local capture attempts on 2026-05-08:

```text
screencapture -x /private/tmp/handrail-desktop-probe.png
could not create image from display
```

`/Applications/Codex.app/Contents/Info.plist` confirms:

```text
CFBundleIdentifier = com.openai.codex
CFBundleShortVersionString = 26.506.31004
```

CoreGraphics and process-inspection probes also did not produce usable references:

```text
CGWindowListCopyWindowInfo probe for Codex windows: no Codex window metadata returned.
ps aux | rg -i '[C]odex|[O]penAI': operation not permitted.
```

`~/Library/Application Support/Codex` exists as an Electron application-support directory, but it does not contain the required reference screenshots. A targeted search for `*.png`, `*.jpg`, `*.jpeg`, and `*.webp` under that directory returned no files.

Repository artifact search found one older Codex-named image:

```text
test-artifacts/codex-desktop-sync-before-2026-04-27.png
PNG image data, 3456 x 2234
MD5 = 21df6ca737eef62c20e6fb313b2552bb
```

This file does not satisfy `../reference-capture-manifest.md` because the manifest requires current Codex Desktop screenshots captured from the user's visible Mac app and stored under this `references/` directory with the listed `desktop-*.png` names.

The remaining focused-composer simulator gap is also environment-blocked:

```text
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
Could not write domain com.apple.iphonesimulator; exiting
```

Additional focused-composer keyboard attempt on 2026-05-08:

```text
XcodeBuildMCP launched Handrail on iPhone 17 with --handrail-preview-data.
Completed checkout composer focused and accepted typed text.
XcodeBuildMCP screenshot still showed no visible software keyboard.
osascript Simulator Command-K attempt failed because the Simulator application was not addressable from the sandbox.
Direct xcrun simctl ui help still could not connect to CoreSimulatorService from the shell sandbox.
```

The required `.png` files from `../reference-capture-manifest.md` remain pending. The reference manifest and clone matrix also still carry blocked status rows because the desktop comparison has not happened.

## Current Re-Audit

2026-05-08 19:02 EDT:

- `references/` still contains only this blocker note.
- No required `desktop-*.png` files exist under `docs/design/phase-1-codex-clone-mockups/`.
- No `focused-composer-keyboard.jpg`, `focused-composer-keyboard-waiver.md`, or `reference-comparison-review.md` exists under the repository.
- A sweep of recent PNG/JPEG evidence under the repository found no newly added capture files.
- A sweep of common manual capture locations found `/private/tmp/codex-vision-logo-source.png`, a 900x900 logo image that does not satisfy any desktop reference row.
- `verify-evidence.sh` still exits nonzero on missing desktop references, missing keyboard evidence or waiver, missing comparison review, blocked or weak clone-matrix rows, and uncaptured manifest rows.

2026-05-08 19:36 EDT:

- `references/` still contains only this blocker note.
- `verify-evidence.sh` still exits nonzero.
- The first hard failures remain the missing required `desktop-*.png` reference captures.
- The remaining verifier failures are unchanged: missing focused-composer keyboard evidence or waiver, missing completed reference comparison review, blocked or weak clone-matrix rows, clone-matrix rows without `PASS`, and uncaptured desktop-reference manifest rows.

2026-05-08 19:58 EDT:

- XcodeBuildMCP relaunched Handrail on iPhone 17 with `--handrail-preview-data`.
- The `Completed checkout` chat opened, the bottom `Ask Codex` composer focused, and the composer accepted typed text.
- XcodeBuildMCP captured a 368x800 JPEG, but the visible software keyboard was still absent.
- Shell `xcrun simctl` preference inspection failed with `CoreSimulatorService connection became invalid`.
- Shell `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO` failed with `Could not write domain com.apple.iphonesimulator; exiting`.
- No `focused-composer-keyboard.jpg` was saved because the captured image does not satisfy the focused-composer keyboard requirement.

2026-05-08 20:16 EDT:

- Spotlight metadata search for the exact eleven required `desktop-*.png` file names returned no matches.
- Spotlight metadata search for `focused-composer-keyboard.jpg`, `focused-composer-keyboard-waiver.md`, and `reference-comparison-review.md` returned no matches.
- `references/` still contains only this blocker note.
- No `focused-composer-keyboard.jpg`, `focused-composer-keyboard-waiver.md`, or `reference-comparison-review.md` exists under the handoff package or simulator artifact directory.

2026-05-08 20:17 EDT:

- `verify-evidence.sh` now sets a deterministic tool `PATH` internally, so sparse-shell command lookup no longer masks evidence failures.
- `verify-evidence.sh` still exits nonzero on the same completion gates: missing required `desktop-*.png` reference captures, missing focused-composer keyboard evidence or waiver, missing completed reference comparison review, blocked or weak clone-matrix rows, clone-matrix rows without `PASS`, and uncaptured desktop-reference manifest rows.

2026-05-08 20:21 EDT:

- A fresh shell display-capture probe failed again: `screencapture -x /private/tmp/handrail-desktop-probe.png` returned `could not create image from display`.
- No `/private/tmp/handrail-desktop-probe.png` file was created, so there is no local desktop screenshot source available through this path.

2026-05-08 20:26 EDT:

- `../focused-composer-keyboard-waiver.md` now exists and is accepted by `../verify-evidence.sh`.
- The remaining verifier failures are the missing required desktop reference captures, missing completed reference comparison review, clone-matrix rows without `PASS`, rows still marked `REFERENCE BLOCKED`, and uncaptured desktop-reference manifest rows.

2026-05-08 20:31 EDT:

- Common manual screenshot locations were searched for recent image files: `~/Desktop`, `~/Downloads`, and `~/Pictures`.
- No required `desktop-*.png` reference file exists in `references/`.
- Recent generic screenshots exist outside the handoff package, but they do not satisfy the manifest because they are not stored under `references/` with the required names and have not been verified as current Codex Desktop states.
- The desktop-sized candidates in `~/Desktop` were visually inspected. They show Comet/X pages, cropped theorem or post text, and a ChatGPT connector menu, not Codex Desktop.
- The recent `~/Downloads` screenshot files are 1170x2532 phone-sized images, so they cannot satisfy the Codex Desktop reference manifest.

2026-05-08 20:46 EDT:

- Exact-name filesystem search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`.
- The searched names were the eleven manifest files: `desktop-chat-list.png`, `desktop-new-chat.png`, `desktop-active-thread.png`, `desktop-running-thinking.png`, `desktop-approval-required.png`, `desktop-approval-result.png`, `desktop-file-artifact.png`, `desktop-diff-artifact.png`, `desktop-error.png`, `desktop-search.png`, and `desktop-settings-menu.png`.

2026-05-08 20:54 EDT:

- A fresh direct directory inspection found that `references/` still contains only `BLOCKED.md`.
- A fresh exact-file check under `references/` reported all eleven required `desktop-*.png` files missing.
- `reference-comparison-review.md` is still absent, so the desktop-reference comparison gate remains blocked on missing desktop inputs.

2026-05-08 21:06 EDT:

- A fresh direct directory inspection again found that `references/` contains only `BLOCKED.md`.
- A fresh exact-file check under `references/` again reported all eleven required `desktop-*.png` files missing.
- `reference-comparison-review.md` is still absent.
- Spotlight exact-name search for the eleven required `desktop-*.png` filenames returned no matches.
- A broader exact-name `find /Users/velocityworks ...` search produced no matches before ending with `find: fts_read: Interrupted system call`; this search is not exhaustive evidence because it did not complete cleanly.

2026-05-08 21:12 EDT:

- A bounded exact-name `find /Users/velocityworks ...` search pruned `Library`, `.Trash`, `.cache`, `Library/Developer`, and `Library/Containers`.
- That bounded search exited cleanly with no errors and found no required `desktop-*.png` files.

2026-05-08 21:48 EDT:

- A fresh direct directory inspection found that `references/` still contains only `BLOCKED.md`.
- `system_profiler SPDisplaysDataType` reported the Apple M1 Max GPU but no attached display detail usable for screenshot capture.
- `osascript -e 'tell application "System Events" to get name of every process whose background only is false'` failed with error `-10827`, so shell GUI process enumeration is not available from this session.
- `/Applications/Codex.app/Contents/Info.plist` remains readable and confirms bundle identifier `com.openai.codex` and version `26.506.31004`, but app bundle metadata is not a desktop reference screenshot.

2026-05-08 21:53 EDT:

- A fresh exact-name filesystem search found no required desktop reference PNGs under `/Users/velocityworks/IdeaProjects`, `~/Desktop`, `~/Downloads`, `~/Pictures`, or `/private/tmp`.
- `../verify-evidence.sh` still exits nonzero on the missing desktop references, missing comparison review, blocked clone-matrix rows, and uncaptured manifest rows.

## Unblock Contract

Place current Codex Desktop screenshots in this directory with these exact names:

- `desktop-chat-list.png`
- `desktop-new-chat.png`
- `desktop-active-thread.png`
- `desktop-running-thinking.png`
- `desktop-approval-required.png`
- `desktop-approval-result.png`
- `desktop-file-artifact.png`
- `desktop-diff-artifact.png`
- `desktop-error.png`
- `desktop-search.png`
- `desktop-settings-menu.png`

After those files exist:

- Run `../check-desktop-references.sh` from the repository root. Do not update the manifest, matrix, or review until it exits cleanly.
- Compare the desktop references against `test-artifacts/phase-1-codex-clone-20260508/` using `../reference-comparison-map.md`; the map must contain exactly the approved mapped desktop-reference-to-simulator pairs with no missing or unexpected pairs.
- Record `../reference-comparison-review.md` with a nonblank reviewer/date, the mockup board, clone matrix, every desktop and simulator input, concrete findings and required-corrections content, no blank template bullets or template instruction text, `Decision: PASS.`, `QC hard rejection review: PASS.`, exactly the approved mapped desktop-reference-to-simulator pairs with no missing or unexpected pairs, and `PASS` in every comparison-result cell.
- Update `../clone-matrix.md` so every table row has `PASS` in the QC Status cell and no table row still contains `REFERENCE BLOCKED`.
- Update `../reference-capture-manifest.md` so every required desktop reference row has `Captured` in the Status column.

Verification command:

```sh
docs/design/phase-1-codex-clone-mockups/verify-evidence.sh
```

The command must exit cleanly before the desktop-reference gate can move from blocked to complete.

For capture steps, use `../desktop-reference-capture-runbook.md`.
