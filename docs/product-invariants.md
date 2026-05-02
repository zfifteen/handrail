# Handrail Product Invariants

Handrail is a free, local-first iOS remote control for Codex Desktop chats on the user's Mac.

The product is useful because Codex Desktop remains local and authoritative. Handrail lets the user see, continue, supervise, approve, deny, and stop Codex Desktop work from iPhone or iPad without turning the project into a cloud workspace or generic remote shell.

## What Handrail Is

- A local iPhone and iPad companion for Codex Desktop on the user's Mac.
- A local WebSocket client for the Handrail CLI running on the user's network.
- A supervisor for Codex Desktop chats, approvals, input, notifications, and status.
- A free product with no account, payment, cloud relay, or hosted execution path.

## What Handrail Must Not Become

Handrail must not become:

- A cloud coding workspace.
- A cloud relay or hosted chat store.
- An account system, login system, or cross-device identity service.
- A paid product or in-app purchase surface.
- A generic terminal, SSH client, or arbitrary shell executor.
- A multi-agent control plane.
- A client for Claude, Gemini, OpenCode, or any non-Codex agent.
- An iOS file editor that bypasses Codex Desktop.

If a proposed change moves toward one of those surfaces, the agent must stop and record the smallest product decision needed before implementation.

## Release Gates

Milestones and releases must be checked against this contract before they are called ready.

- App Store metadata and screenshots must describe a local Codex Desktop remote, not a cloud IDE, account product, generic terminal, or multi-agent workspace.
- Privacy copy must state that Handrail uses local `ws://` on the user's Wi-Fi/LAN, protected by a per-device pairing token, and sends no data to the public internet by design.
- Protocol changes must preserve local Codex Desktop ownership and must not silently drop unknown CLI/iOS message drift.
- App Store readiness needs artifact evidence: signed Release entitlements where applicable, hosted privacy policy URL, store metadata, screenshots, and QA evidence for affected visible flows.
- iPhone and iPad UI claims require simulator validation. CLI tests or Swift unit tests alone do not prove visible UI behavior.
- iPad and watchOS claims must stay out of iPhone App Store metadata until those platform milestones have their own verification evidence.

## Agent Check

Every role report should include:

```markdown
## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes/no.
- Drift risk found: `<risk>` or `No product-invariant drift found`.
```

This check is not a slogan. It is the release gate that keeps Handrail's public promise, implementation, and validation evidence aligned.
