# Handrail Privacy Policy

**Last updated:** 2026-04-30

Handrail is a local-first iOS companion app for the Handrail desktop CLI. It is designed to work on your own devices and local network.

## Summary

- Handrail does not require an account.
- Handrail does not sell personal data.
- Handrail does not run analytics or telemetry by default.
- Handrail communicates with your Mac over your local network using an unencrypted WebSocket connection secured by a per-device pairing token.

## Data Handrail Stores

Handrail stores the following data on your iPhone/iPad:

- **Pairing token (Keychain):** a secret token used to authenticate to your Mac’s Handrail server.
- **Paired machine metadata (UserDefaults):** non-secret details such as machine name, host, and port.
- **Local notification history (on-device):** if you enable notifications, iOS may keep notification entries visible in the system notification center.

Handrail may display content from your Mac’s Codex Desktop chats (including text that may contain personal or sensitive information) when your iPhone/iPad is paired and connected to your Mac.

## Data Handrail Does Not Collect

Handrail does not:

- Create a cloud account.
- Upload your chat content to a Handrail-owned server.
- Collect location data.
- Collect advertising identifiers.

## Network Use

Handrail connects to the Handrail CLI server running on your Mac over your local Wi‑Fi/LAN. This connection uses:

- `ws://` (no TLS encryption)
- A pairing token required to connect

No data is intentionally sent to the public internet by Handrail as part of the product’s core function.

## Notifications

Handrail may request permission to show notifications. Notifications can include chat titles and brief status summaries (for example, completion, failure, or approval-required states). You can disable notifications in iOS Settings at any time.

## Sharing

Handrail does not share your data with third parties because it does not operate a backend service for your data.

## Data Retention

Handrail retains the pairing token and paired-machine metadata until you unpair or delete the app.

## Security

Handrail stores the pairing token in the iOS Keychain. Local-network communication is protected by the token but is not encrypted in transit. Use Handrail only on networks you trust.

## Contact

For support or privacy questions, contact the developer using the support channel listed on the App Store product page (once published).

## Changes

If this policy changes, the “Last updated” date will be updated. The newest version in the source repository is the authoritative text before App Store publication.
