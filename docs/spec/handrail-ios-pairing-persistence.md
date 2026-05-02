# Handrail iOS Pairing Persistence

This document records the iOS pairing persistence contract that lets Handrail reconnect to the user's local Mac without storing the pairing token in `UserDefaults`.

Related source:

- `ios/Handrail/Handrail/Models/HandrailModels.swift`
- `ios/Handrail/Handrail/Stores/HandrailStore.swift`
- `ios/Handrail/Handrail/Utilities/KeychainStore.swift`
- `ios/Handrail/HandrailTests/PairingPersistenceTests.swift`

## Boundary

Observed:

- QR pairing produces a `PairingPayload` with protocol version, host, port, token, and machine name.
- iOS stores host, port, protocol version, and machine name in `UserDefaults` under `handrail.pairedMachine`.
- iOS stores the pairing token in Keychain account `paired-machine-token`.
- On launch, iOS reconstructs `PairedMachine` from `UserDefaults` metadata plus the Keychain token.
- Legacy `UserDefaults` records that still include the token are decoded once and migrated through the current save path.
- Corrupt pairing data becomes a visible Handrail error with a repair instruction.

Inferred:

- The pairing token is the local authorization secret for the CLI WebSocket `hello` message.
- If metadata and legacy decoding both fail, the app cannot safely infer a machine or token.

Unknown:

- Whether future pairing payloads need a schema version beyond `protocolVersion`.

## Failure Contract

Malformed `UserDefaults` pairing data must not silently leave `pairedMachine` nil.

The visible error is:

```text
Stored pairing data is corrupt. Reset pairing, then pair Handrail with your Mac again.
```

If metadata decodes but the Keychain token is absent, the visible error is:

```text
Stored pairing metadata is missing its Keychain token. Reset pairing, then pair Handrail with your Mac again.
```

The invariant is:

```text
A persisted local pairing can be absent, valid, migrated, or visibly invalid; it must not fail invisibly.
```
