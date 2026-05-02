# Simulator Diagnostics

## Strongest Finding

The simulator is not currently the primary blocker. Direct shell `xcodebuild`, `simctl`, and the QA sweep path all work in the current full-access execution context. The recurring impediment is a mixture of one historical CoreSimulator access/daemon failure, one deterministic sweep-script bug, and several validation tasks that need live Handrail data states the simulator does not currently contain.

## Current Verified State

- Xcode version: `Xcode 26.4.1`, build `17E202`.
- Available iOS simulator runtime: iOS 26.4.1.
- Direct `xcodebuild -showdestinations` lists the expected iPhone and iPad simulators.
- Direct shell simulator tests work:
  - `RootLayoutSelectionTests`: passed 7/7 on `iPad Pro 13-inch (M5)` (`43913CAF-14DD-45B6-9633-0A9790474FC7`).
  - Focused iPad set: passed 29/29 on the same simulator.
- Direct sweep script execution works:
  - iPhone: `0E58E7BB-44FA-4BEE-9C94-8FED4C334482`.
  - iPad: `43913CAF-14DD-45B6-9633-0A9790474FC7`.
  - Explicit UDID output: `test-artifacts/qa-simulator-sweep-2026-05-01-183710/`.
  - Default-name output after the script fix: `test-artifacts/qa-simulator-sweep-2026-05-01-183925/`.

## Failure Class 1: CoreSimulator Access Or Daemon Failure

The 2026-05-01 08:02 daily sweep log shows a real CoreSimulator-layer failure:

- `CoreSimulatorService connection became invalid.`
- `Error opening log file ... Operation not permitted`.
- `Could not kickstart simdiskimaged`.
- `simdiskimaged crashed or is not responding`.
- `Unable to locate device set`.

This is not an app test failure. It happened before the app could build, boot, or launch. The most likely trigger is the older restricted execution context trying to use CoreSimulator paths under `~/Library/Developer/CoreSimulator` and `~/Library/Logs/CoreSimulator`. In the current full-access context, the same machine can list devices, boot devices, build, test, install, launch, and screenshot.

## Failure Class 2: QA Sweep Script Name Resolution Bug

`tools/qa/simulator_sweep.sh` used this macOS-incompatible awk form:

```bash
match($0, /\(([0-9A-F-]+)\)/, m)
```

The third argument to `match` is not supported by the default macOS `awk`, so device name resolution failed with:

```text
awk: syntax error at source line 3
context is
          match($0, >>>  /\(([0-9A-F-]+)\)/, <<<
awk: illegal statement at source line 3
```

The follow-on message says `error: simulator device not found: 'iPhone 17'`, but that conclusion is false. The iPhone 17 simulator exists; the parser failed before it could extract the UDID.

There was also a stale default iPad name:

```bash
IPAD_DEVICE="${IPAD_DEVICE:-iPad Pro (13-inch) (M4)}"
```

The installed simulator is named `iPad Pro 13-inch (M5)`. After the awk bug was removed, the default iPhone target also proved ambiguous because both iOS 26.1 and iOS 26.4 include an `iPhone 17`.

This diagnostic run fixed the script by:

- Replacing the incompatible awk parser with Bash string matching.
- Adding explicit runtime selection with `IPHONE_RUNTIME` and `IPAD_RUNTIME`.
- Defaulting both runtimes to `iOS 26.4`.
- Updating the default iPad device name to `iPad Pro 13-inch (M5)`.

The fixed script passed with default settings and captured iPhone/iPad screenshots under `test-artifacts/qa-simulator-sweep-2026-05-01-183925/`.

## Failure Class 3: Missing Live Validation States

Several open iPad issues are being reported as simulator blockers, but the simulator itself is working. The blocker is the live Desktop-fed data state:

- #21 needs a permitted successful iPad `start_chat` event.
- #22 needs a chat-linked Activity row.
- #24 needs a live `waiting_for_approval` chat row.

The current local feed has running and completed chats only. The simulator cannot honestly validate those closures without the corresponding live state, and project instructions correctly prohibit fabricating validation evidence with test-only launch state.

## Failure Class 4: Tool Boundary Or Transient Timeout

A prior QA report recorded an XcodeBuildMCP `test_sim` timeout at a 120-second tool boundary. Current evidence does not show a persistent test-runtime problem:

- Direct 7-test shell run completed successfully.
- Direct 29-test shell run completed successfully with `29.610` seconds of test execution.
- XcodeBuildMCP also passed the 29-test focused set in a later run.

Treat the timeout as transient or tool-boundary evidence unless it reproduces with a saved `.xcresult` or a full command log.

## Practical Interpretation

Simulator work is healthy when it uses a full-access execution context and deterministic device/runtime selection. The previous unstable path was the unattended sweep's name-resolution step and any automation environment that cannot access CoreSimulator's user-library paths.

The sweep-script cleanup is now applied. The remaining QA process change is to label #21/#22/#24 as live-data validation blockers, not simulator infrastructure blockers.

## Evidence Generated In This Diagnostic Run

- `test-artifacts/simulator-diagnostics-2026-05-01/xcodebuild-root-layout-ipad.log`
- `test-artifacts/simulator-diagnostics-2026-05-01/xcodebuild-focused-29-ipad.log`
- `test-artifacts/simulator-diagnostics-2026-05-01/simulator-sweep-name-resolution.log`
- `test-artifacts/simulator-diagnostics-2026-05-01/simulator-sweep-udid-run.log`
- `test-artifacts/simulator-diagnostics-2026-05-01/simulator-sweep-default-run-after-runtime-fix.log`
- `test-artifacts/qa-simulator-sweep-2026-05-01-183710/iphone-launch.png`
- `test-artifacts/qa-simulator-sweep-2026-05-01-183710/ipad-launch.png`
- `test-artifacts/qa-simulator-sweep-2026-05-01-183925/iphone-launch.png`
- `test-artifacts/qa-simulator-sweep-2026-05-01-183925/ipad-launch.png`
