# iPhone tests inherit corrupt pairing state

## Reproduction

1. Use the current local branch in `/Users/velocityworks/IdeaProjects/handrail`.
2. Target iPhone 17, iOS Simulator 26.4.1, UDID `0E58E7BB-44FA-4BEE-9C94-8FED4C334482`.
3. Ensure the simulator contains stored pairing metadata without the matching Keychain token. This was visible in Settings as `Pairing needs reset` before and after app reset attempts in this sweep.
4. Run the focused iPhone simulator tests:

```sh
XcodeBuildMCP test_sim -only-testing:HandrailTests/TransientErrorStateTests
```

## Expected Behavior

Store-focused tests should construct deterministic state and pass independently of persisted app pairing metadata left in the simulator.

## Observed Behavior

The focused test class failed 3/7 on iPhone 17 because `HandrailStore(enableNetworking: false)` loaded persisted corrupt pairing metadata and set:

```text
Stored pairing metadata is missing its Keychain token. Reset pairing, then pair Handrail with your Mac again.
```

Failing tests:

- `testCommandResultDecodesAndRecordsActivity()`
- `testViewedChatDoesNotRecordApprovalNotification()`
- `testViewedChatDoesNotRecordTaskCompletionNotification()`

The same full `HandrailTests` suite passed 48/48 on iPad Pro 13-inch (M5), iOS Simulator 26.4.1, where the paired simulator state was valid.

## Evidence

- `test-artifacts/qa-daily-simulator-sweep-2026-05-02-120233/iphone-settings.jpg`
- `test-artifacts/qa-daily-simulator-sweep-2026-05-02-120233/iphone-settings-after-reset.jpg`
- Daily sweep notes: `test-artifacts/qa-daily-simulator-sweep-2026-05-02-120233/summary.md`

## Affected Surface

iOS simulator test reliability for `HandrailTests`; the failure is state-dependent and can hide or fabricate regressions during QA sweeps.
