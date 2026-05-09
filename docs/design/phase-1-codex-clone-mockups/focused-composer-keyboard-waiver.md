# Focused Composer Keyboard Waiver

## Waiver Decision

Decision: Waive the focused-composer visible software-keyboard screenshot requirement for Phase 1.

## Reason

`test-artifacts/phase-1-codex-clone-20260508/focused-composer.jpg` captures the required focused composer state: the `Ask Codex` field is focused, typed input is present, and the send action is enabled. The visible software-keyboard screenshot is waived because the current validation environment keeps the Simulator hardware-keyboard state active and blocks both available deterministic controls for changing it: shell `xcrun simctl` cannot connect to CoreSimulatorService, and `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO` cannot write the Simulator preference domain. XcodeBuildMCP focus and typing worked, but its screenshot still showed no visible software keyboard.

## Existing Evidence

- `test-artifacts/phase-1-codex-clone-20260508/focused-composer.jpg` captures composer focus, typed input, and enabled Send.
- `docs/design/phase-1-codex-clone-mockups/references/BLOCKED.md` records the failed Simulator keyboard-control attempts.

## Reviewer

Name: Codex local validation agent

Date: 2026-05-08
